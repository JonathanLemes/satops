import Fastify, { type FastifyReply, type FastifyRequest } from "fastify";
import { timingSafeEqual } from "node:crypto";
import { config } from "./config.ts";
import { pool, withTx } from "./db.ts";
import { FAULT_MODES, isFaultMode } from "./faults.ts";
import { move, newId, toApiRecord, upsertRecord, type RecordRow } from "./ledger.ts";
import { btcToSats, rpc, satsToBtc } from "./rpc.ts";
import { getFaults, setFault } from "./state.ts";
import { flush, redeliver } from "./webhooks.ts";

function authorized(req: FastifyRequest): boolean {
  const header = req.headers.authorization ?? "";
  const expected = Buffer.from(`Bearer ${config.apiToken}`);
  const given = Buffer.from(header);
  return expected.length === given.length && timingSafeEqual(expected, given);
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export function buildServer() {
  const app = Fastify({ logger: { level: "info" }, bodyLimit: 64 * 1024 });

  app.addHook("onRequest", async (req, reply) => {
    if (!req.url.startsWith("/v1/")) return;
    if (!authorized(req)) return reply.code(401).send({ error: "unauthorized" });
    const faults = getFaults();
    if (faults.temporary_api_outage && !req.url.startsWith("/v1/faults")) return reply.code(503).send({ error: "simulated_outage" });
    if (faults.delay_response && faults.delayMs > 0 && !req.url.startsWith("/v1/faults")) await sleep(faults.delayMs);
  });

  app.get("/health", async () => {
    const chain = await rpc<{ chain: string }>("getblockchaininfo").then((i) => i.chain).catch(() => "unreachable");
    const active = Object.entries(getFaults()).filter(([k, v]) => v === true && k !== "delayMs").map(([k]) => k);
    return { status: chain === "regtest" ? "ok" : "degraded", chain, simulatedFaults: active };
  });

  app.get("/v1/faults", async () => ({ allowed: config.faultModesAllowed, faults: getFaults(), modes: FAULT_MODES }));

  app.post<{ Body: { mode: string; enabled: boolean; delayMs?: number } }>("/v1/faults", async (req, reply) => {
    if (!config.faultModesAllowed) return reply.code(403).send({ error: "fault_modes_disabled" });
    const { mode, enabled, delayMs } = req.body ?? ({} as never);
    if (!isFaultMode(mode) || typeof enabled !== "boolean") return reply.code(400).send({ error: "invalid_fault" });
    await setFault(mode, enabled, Math.min(Math.max(Number(delayMs ?? 0), 0), 30_000));
    req.log.warn({ mode, enabled }, "SIMULATED FAULT MODE CHANGED");
    return { faults: getFaults() };
  });

  app.get("/v1/customers", async () => {
    const { rows } = await pool.query(
      "SELECT c.id, c.name, c.external_ref, COALESCE(b.available_sats,0)::bigint AS available, COALESCE(b.pending_sats,0)::bigint AS pending, COALESCE(b.reserved_sats,0)::bigint AS reserved FROM customers c LEFT JOIN balances b ON b.customer_id = c.id ORDER BY c.created_at",
    );
    return { customers: rows.map((r) => ({ id: r.id, name: r.name, externalRef: r.external_ref, availableSats: Number(r.available), pendingSats: Number(r.pending), reservedSats: Number(r.reserved) })) };
  });

  app.post<{ Body: { name?: string; externalRef?: string } }>("/v1/customers", async (req) => {
    const externalRef = req.body?.externalRef ?? null;
    if (externalRef) {
      const { rows } = await pool.query("SELECT id FROM customers WHERE external_ref = $1", [externalRef]);
      if (rows[0]) return { id: rows[0].id, existing: true };
    }
    const id = newId("cus");
    await withTx(async (c) => {
      await c.query("INSERT INTO customers (id, name, external_ref) VALUES ($1, $2, $3)", [id, String(req.body?.name ?? "Synthetic customer").slice(0, 80), externalRef]);
      await c.query("INSERT INTO balances (customer_id) VALUES ($1)", [id]);
    });
    return { id };
  });

  app.post<{ Params: { id: string } }>("/v1/customers/:id/deposit-addresses", async (req, reply) => {
    const { rows } = await pool.query("SELECT id FROM customers WHERE id = $1", [req.params.id]);
    if (!rows[0]) return reply.code(404).send({ error: "not_found" });
    const address = await rpc<string>("getnewaddress", [req.params.id, "bech32"], config.wallet);
    await pool.query("INSERT INTO deposit_addresses (address, customer_id) VALUES ($1, $2)", [address, req.params.id]);
    return { address };
  });

  app.get("/v1/deposit-addresses", async () => {
    const { rows } = await pool.query("SELECT address, customer_id FROM deposit_addresses ORDER BY created_at");
    return { addresses: rows.map((r) => ({ address: r.address, customerId: r.customer_id })) };
  });

  app.get("/v1/records", async () => {
    const { rows } = await pool.query<RecordRow>("SELECT * FROM records ORDER BY occurred_at");
    const watermark = rows.reduce((max, r) => (r.updated_at > max ? r.updated_at : max), new Date(0));
    return { records: rows.map(toApiRecord), watermark: watermark.toISOString() };
  });

  app.get("/v1/balances", async () => {
    const { rows } = await pool.query("SELECT customer_id, available_sats, pending_sats, reserved_sats FROM balances ORDER BY customer_id");
    const offset = getFaults().invalid_balance_projection ? 1_234 : 0;
    return {
      balances: rows.map((r) => ({ customerId: r.customer_id, availableSats: Number(r.available_sats) + offset, pendingSats: Number(r.pending_sats), reservedSats: Number(r.reserved_sats) })),
      asOf: new Date().toISOString(),
    };
  });

  app.post<{ Body: { customerId: string; amountSats: number; address: string; idempotencyKey: string } }>("/v1/withdrawals", async (req, reply: FastifyReply) => {
    const { customerId, amountSats, address, idempotencyKey } = req.body ?? ({} as never);
    if (!customerId || !Number.isSafeInteger(amountSats) || amountSats < 546 || !address || !idempotencyKey) return reply.code(400).send({ error: "invalid_request" });

    const existing = await pool.query<RecordRow>("SELECT * FROM records WHERE idempotency_key = $1", [idempotencyKey]);
    if (existing.rows[0]) return { ...toApiRecord(existing.rows[0]), replayed: true };

    const id = newId("wdr");
    const fee = 1_000;
    try {
      await withTx(async (c) => {
        const { rows } = await c.query("SELECT available_sats FROM balances WHERE customer_id = $1 FOR UPDATE", [customerId]);
        if (!rows[0] || Number(rows[0].available_sats) < amountSats + fee) throw new Error("insufficient_funds");
        await move(c, customerId, "available", -(amountSats + fee), `reserve:${id}`);
        await move(c, customerId, "reserved", amountSats + fee, `reserve:${id}`);
        await c.query("INSERT INTO records (id, kind, customer_id, amount_sats, fee_sats, address, status, idempotency_key) VALUES ($1, 'withdrawal', $2, $3, $4, $5, 'pending', $6)", [id, customerId, amountSats, fee, address, idempotencyKey]);
      });
    } catch (error) {
      if (String(error).includes("insufficient_funds")) return reply.code(409).send({ error: "insufficient_funds" });
      throw error;
    }

    let txid: string;
    try {
      txid = await rpc<string>("sendtoaddress", [address, satsToBtc(amountSats)], config.wallet);
    } catch (error) {
      await withTx(async (c) => {
        await move(c, customerId, "reserved", -(amountSats + fee), `release:${id}`);
        await move(c, customerId, "available", amountSats + fee, `release:${id}`);
        const { rows } = await c.query<RecordRow>("SELECT * FROM records WHERE id = $1", [id]);
        await upsertRecord(c, { ...rows[0]!, amount_sats: amountSats, fee_sats: fee, status: "failed" });
      });
      return reply.code(502).send({ error: "broadcast_failed", message: String(error) });
    }

    const record = await withTx(async (c) => {
      await c.query("UPDATE records SET txid = $2 WHERE id = $1", [id, txid]);
      const { rows } = await c.query<RecordRow>("SELECT * FROM records WHERE id = $1", [id]);
      return upsertRecord(c, { ...rows[0]!, amount_sats: amountSats, fee_sats: fee, status: "broadcast" });
    });

    if (getFaults().timeout_after_success) {
      await sleep(15_000);
      return reply.code(504).send({ error: "gateway_timeout" });
    }
    return toApiRecord(record);
  });

  app.post<{ Body: { from: string; to: string; amountSats: number; idempotencyKey: string } }>("/v1/transfers", async (req, reply) => {
    const { from, to, amountSats, idempotencyKey } = req.body ?? ({} as never);
    if (!from || !to || from === to || !Number.isSafeInteger(amountSats) || amountSats <= 0 || !idempotencyKey) return reply.code(400).send({ error: "invalid_request" });
    const existing = await pool.query("SELECT id FROM records WHERE idempotency_key = $1", [`${idempotencyKey}:out`]);
    if (existing.rows[0]) return { replayed: true };
    try {
      await withTx(async (c) => {
        const { rows } = await c.query("SELECT customer_id, available_sats FROM balances WHERE customer_id = ANY($1) ORDER BY customer_id FOR UPDATE", [[from, to]]);
        const src = rows.find((r) => r.customer_id === from);
        if (!src || Number(src.available_sats) < amountSats) throw new Error("insufficient_funds");
        await move(c, from, "available", -amountSats, `transfer:${idempotencyKey}`);
        await move(c, to, "available", amountSats, `transfer:${idempotencyKey}`);
        for (const [kind, cust, suffix] of [["transfer_out", from, "out"], ["transfer_in", to, "in"]] as const) {
          await c.query("INSERT INTO records (id, kind, customer_id, amount_sats, status, idempotency_key) VALUES ($1, $2, $3, $4, 'completed', $5)", [newId("trf"), kind, cust, amountSats, `${idempotencyKey}:${suffix}`]);
        }
      });
    } catch (error) {
      if (String(error).includes("insufficient_funds")) return reply.code(409).send({ error: "insufficient_funds" });
      throw error;
    }
    return { ok: true };
  });

  app.post("/v1/test/webhooks/flush", async () => ({ delivered: await flush(500) }));

  app.post<{ Body: { times?: number; last?: number; order?: string } }>("/v1/test/webhooks/redeliver", async (req) => {
    const times = Math.min(Math.max(Number(req.body?.times ?? 1), 1), 100);
    const last = Math.min(Math.max(Number(req.body?.last ?? 10), 1), 100);
    return redeliver(last, times, req.body?.order === "reverse" ? "reverse" : "forward");
  });

  app.get("/v1/wallet", async () => {
    const balance = await rpc<string>("getbalance", [], config.wallet);
    return { wallet: config.wallet, balanceSats: btcToSats(balance) };
  });

  return app;
}
