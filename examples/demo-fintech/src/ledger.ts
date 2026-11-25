import { randomBytes } from "node:crypto";
import type { Tx } from "./db.ts";
import { enqueueWebhook } from "./webhooks.ts";

export function newId(prefix: string): string {
  return `${prefix}_${randomBytes(8).toString("hex")}`;
}

export async function move(client: Tx, customerId: string, bucket: "available" | "pending" | "reserved", amount: number, reference: string) {
  await client.query("INSERT INTO balances (customer_id) VALUES ($1) ON CONFLICT DO NOTHING", [customerId]);
  await client.query(`UPDATE balances SET ${bucket}_sats = ${bucket}_sats + $2 WHERE customer_id = $1`, [customerId, amount]);
  await client.query("INSERT INTO entries (customer_id, bucket, amount_sats, reference) VALUES ($1, $2, $3, $4)", [customerId, bucket, amount, reference]);
}

export interface RecordRow {
  id: string;
  kind: string;
  customer_id: string;
  amount_sats: string;
  fee_sats: string;
  txid: string | null;
  vout: number | null;
  status: string;
  occurred_at: Date;
  updated_at: Date;
}

export function toApiRecord(r: RecordRow) {
  return {
    id: r.id,
    kind: r.kind,
    customerId: r.customer_id,
    asset: "BTC",
    amountSats: Number(r.amount_sats),
    feeSats: Number(r.fee_sats),
    txid: r.txid,
    vout: r.vout,
    status: r.status,
    occurredAt: r.occurred_at.toISOString(),
    updatedAt: r.updated_at.toISOString(),
  };
}

export async function upsertRecord(client: Tx, record: Omit<RecordRow, "occurred_at" | "updated_at" | "amount_sats" | "fee_sats"> & { amount_sats: number; fee_sats?: number }) {
  const { rows } = await client.query<RecordRow>(
    `INSERT INTO records (id, kind, customer_id, amount_sats, fee_sats, txid, vout, status)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status, amount_sats = EXCLUDED.amount_sats, updated_at = now()
     RETURNING *`,
    [record.id, record.kind, record.customer_id, record.amount_sats, record.fee_sats ?? 0, record.txid, record.vout, record.status],
  );
  await enqueueWebhook(client, { type: `record.${record.status}`, record: toApiRecord(rows[0]!) });
  return rows[0]!;
}
