import { config } from "./config.ts";
import { pool, withTx } from "./db.ts";
import { planDeposit, type DepositStatus } from "./deposits.ts";
import { move, newId, upsertRecord, type RecordRow } from "./ledger.ts";
import { btcToSats, rpc } from "./rpc.ts";
import { getFaults } from "./state.ts";

interface WalletTx {
  category: string;
  address?: string;
  amount: string;
  confirmations: number;
  txid: string;
  vout: number;
}

export async function scanDeposits(): Promise<number> {
  const txs = await rpc<WalletTx[]>("listtransactions", ["*", 1000, 0, true], config.wallet);
  const receives = txs.filter((t) => t.category === "receive" && t.address);
  if (receives.length === 0) return 0;

  const { rows: addressRows } = await pool.query<{ address: string; customer_id: string }>(
    "SELECT address, customer_id FROM deposit_addresses WHERE address = ANY($1)",
    [receives.map((r) => r.address)],
  );
  const owner = new Map(addressRows.map((r) => [r.address, r.customer_id]));
  let changed = 0;

  for (const receive of receives) {
    const customerId = owner.get(receive.address!);
    if (!customerId) continue;
    const amountSats = btcToSats(receive.amount);

    changed += await withTx(async (client) => {
      const { rows } = await client.query<RecordRow>(
        "SELECT * FROM records WHERE kind = 'deposit' AND txid = $1 AND vout = $2 ORDER BY occurred_at FOR UPDATE",
        [receive.txid, receive.vout],
      );
      const current = (rows[0]?.status as DepositStatus | undefined) ?? null;
      const plan = planDeposit({ txid: receive.txid, vout: receive.vout, amountSats, confirmations: receive.confirmations }, current, config.requiredConfirmations, getFaults());
      if (!plan || plan.status === current) return 0;

      if (plan.status === "pending" && current === null) {
        await upsertRecord(client, { id: newId("dep"), kind: "deposit", customer_id: customerId, amount_sats: amountSats, txid: receive.txid, vout: receive.vout, status: "pending" });
        await move(client, customerId, "pending", amountSats, `deposit:${receive.txid}:${receive.vout}`);
        return 1;
      }

      if (plan.status === "credited") {
        const base = rows[0];
        if (current === "pending") await move(client, customerId, "pending", -amountSats, `settle:${receive.txid}:${receive.vout}`);
        const first = base ?? { id: newId("dep") };
        await upsertRecord(client, { id: first.id, kind: "deposit", customer_id: customerId, amount_sats: plan.creditedAmountSats, txid: receive.txid, vout: receive.vout, status: "credited" });
        await move(client, customerId, "available", plan.creditedAmountSats, `credit:${receive.txid}:${receive.vout}`);
        for (let i = 1; i < plan.creditCount; i++) {
          await upsertRecord(client, { id: newId("dep"), kind: "deposit", customer_id: customerId, amount_sats: plan.creditedAmountSats, txid: receive.txid, vout: receive.vout, status: "credited" });
          await move(client, customerId, "available", plan.creditedAmountSats, `credit-dup:${receive.txid}:${receive.vout}`);
        }
        return 1;
      }

      if (plan.status === "reversed") {
        for (const row of rows.filter((r) => r.status === "credited")) {
          const { rows: bal } = await client.query<{ available_sats: string }>("SELECT available_sats FROM balances WHERE customer_id = $1 FOR UPDATE", [customerId]);
          const take = Math.min(Number(bal[0]?.available_sats ?? 0), Number(row.amount_sats));
          await move(client, customerId, "available", -take, `reverse:${row.id}`);
          await upsertRecord(client, { ...row, amount_sats: Number(row.amount_sats), fee_sats: Number(row.fee_sats), status: "reversed" });
        }
        return 1;
      }
      return 0;
    });
  }
  return changed;
}

export async function settleWithdrawals(): Promise<void> {
  const { rows } = await pool.query<RecordRow>("SELECT * FROM records WHERE kind = 'withdrawal' AND status = 'broadcast'");
  for (const row of rows) {
    try {
      const tx = await rpc<{ confirmations: number }>("gettransaction", [row.txid], config.wallet);
      if (tx.confirmations >= 1) {
        await withTx(async (client) => {
          const total = Number(row.amount_sats) + Number(row.fee_sats);
          await move(client, row.customer_id, "reserved", -total, `settle:${row.id}`);
          await upsertRecord(client, { ...row, amount_sats: Number(row.amount_sats), fee_sats: Number(row.fee_sats), status: "completed" });
        });
      }
    } catch {
      continue;
    }
  }
}
