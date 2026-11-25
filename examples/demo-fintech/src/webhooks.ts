import { randomUUID } from "node:crypto";
import { config } from "./config.ts";
import { pool, type Tx } from "./db.ts";
import { getFaults } from "./state.ts";
import { sign } from "./signature.ts";

export async function enqueueWebhook(client: Tx, payload: unknown) {
  if (!config.webhookUrl) return;
  await client.query("INSERT INTO webhook_outbox (delivery_id, payload) VALUES ($1, $2)", [randomUUID(), JSON.stringify(payload)]);
}

async function post(deliveryId: string, payload: unknown): Promise<number> {
  const body = JSON.stringify(payload);
  const res = await fetch(config.webhookUrl, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-demofintech-signature": sign(config.webhookSecret, Math.floor(Date.now() / 1000), body),
      "x-demofintech-delivery": deliveryId,
    },
    body,
    signal: AbortSignal.timeout(5_000),
  });
  return res.status;
}

export async function flush(limit = 50): Promise<number> {
  if (!config.webhookUrl) return 0;
  const { rows } = await pool.query<{ id: string; delivery_id: string; payload: unknown; attempts: number }>(
    "SELECT id, delivery_id, payload, attempts FROM webhook_outbox WHERE status = 'pending' AND next_attempt_at <= now() ORDER BY id LIMIT $1",
    [limit],
  );
  let delivered = 0;
  for (const row of rows) {
    try {
      const status = await post(row.delivery_id, row.payload);
      if (status >= 200 && status < 300) {
        delivered++;
        await pool.query("UPDATE webhook_outbox SET status = 'delivered', attempts = attempts + 1 WHERE id = $1", [row.id]);
        if (getFaults().duplicate_webhook_processing) await post(randomUUID(), row.payload);
      } else {
        throw new Error(`HTTP ${status}`);
      }
    } catch (error) {
      const attempts = row.attempts + 1;
      const delay = Math.min(2 ** attempts * 1000, 300_000) * (0.8 + Math.random() * 0.4);
      await pool.query(
        "UPDATE webhook_outbox SET attempts = $2, last_error = $3, next_attempt_at = now() + ($4 || ' milliseconds')::interval, status = CASE WHEN $2 >= 10 THEN 'failed' ELSE 'pending' END WHERE id = $1",
        [row.id, attempts, String(error), Math.round(delay)],
      );
    }
  }
  return delivered;
}

export async function redeliver(last: number, times: number, order: "forward" | "reverse") {
  const { rows } = await pool.query<{ delivery_id: string; payload: unknown }>(
    "SELECT delivery_id, payload FROM webhook_outbox WHERE status = 'delivered' ORDER BY id DESC LIMIT $1",
    [last],
  );
  const batch = order === "reverse" ? rows : [...rows].reverse();
  let attempts = 0;
  let accepted = 0;
  let duplicates = 0;
  for (let i = 0; i < times; i++) {
    for (const row of batch) {
      attempts++;
      const status = await post(row.delivery_id, row.payload).catch(() => 0);
      if (status === 202) accepted++;
      if (status === 200) duplicates++;
    }
  }
  return { attempts, accepted, duplicates };
}
