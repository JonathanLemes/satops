import pg from "pg";
import { config } from "./config.ts";

export const pool = new pg.Pool({ connectionString: config.databaseUrl, max: 10 });

export type Tx = pg.PoolClient;

export async function withTx<T>(fn: (client: Tx) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await fn(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function migrate(): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS customers (
      id text PRIMARY KEY,
      external_ref text UNIQUE,
      name text NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS deposit_addresses (
      address text PRIMARY KEY,
      customer_id text NOT NULL REFERENCES customers(id),
      created_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS balances (
      customer_id text PRIMARY KEY REFERENCES customers(id),
      available_sats bigint NOT NULL DEFAULT 0,
      pending_sats bigint NOT NULL DEFAULT 0,
      reserved_sats bigint NOT NULL DEFAULT 0,
      CHECK (available_sats >= 0 AND reserved_sats >= 0)
    );
    CREATE TABLE IF NOT EXISTS entries (
      id bigserial PRIMARY KEY,
      customer_id text NOT NULL REFERENCES customers(id),
      bucket text NOT NULL,
      amount_sats bigint NOT NULL,
      reference text NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS records (
      id text PRIMARY KEY,
      kind text NOT NULL,
      customer_id text NOT NULL REFERENCES customers(id),
      amount_sats bigint NOT NULL,
      fee_sats bigint NOT NULL DEFAULT 0,
      txid text,
      vout integer,
      address text,
      status text NOT NULL,
      idempotency_key text UNIQUE,
      occurred_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS records_outpoint ON records (txid, vout);
    CREATE TABLE IF NOT EXISTS webhook_outbox (
      id bigserial PRIMARY KEY,
      delivery_id text NOT NULL,
      payload jsonb NOT NULL,
      status text NOT NULL DEFAULT 'pending',
      attempts integer NOT NULL DEFAULT 0,
      next_attempt_at timestamptz NOT NULL DEFAULT now(),
      last_error text,
      created_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS faults (
      mode text PRIMARY KEY,
      enabled boolean NOT NULL,
      delay_ms integer NOT NULL DEFAULT 0
    );
  `);
}
