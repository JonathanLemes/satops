import { config } from "./config.ts";
import { migrate, pool } from "./db.ts";
import { scanDeposits, settleWithdrawals } from "./chain.ts";
import { ensureWallet } from "./rpc.ts";
import { buildServer } from "./server.ts";
import { loadFaults } from "./state.ts";
import { flush } from "./webhooks.ts";

async function waitForNode() {
  for (let attempt = 1; ; attempt++) {
    try {
      await ensureWallet();
      return;
    } catch (error) {
      const delay = Math.min(1000 * 2 ** attempt, 30_000);
      console.warn(`bitcoin node not ready (${String(error)}), retrying in ${delay}ms`);
      await new Promise((r) => setTimeout(r, delay));
    }
  }
}

async function seedCustomers() {
  const { rows } = await pool.query("SELECT count(*)::int AS n FROM customers");
  for (let i = rows[0].n; i < config.syntheticCustomers; i++) {
    const id = `cus_synthetic_${String(i + 1).padStart(3, "0")}`;
    await pool.query("INSERT INTO customers (id, name, external_ref) VALUES ($1, $2, $1) ON CONFLICT DO NOTHING", [id, `Synthetic customer ${i + 1}`]);
    await pool.query("INSERT INTO balances (customer_id) VALUES ($1) ON CONFLICT DO NOTHING", [id]);
  }
}

async function loop() {
  try {
    await scanDeposits();
    await settleWithdrawals();
    await flush();
  } catch (error) {
    console.error("background loop failed", error);
  } finally {
    setTimeout(loop, config.pollIntervalMs);
  }
}

await migrate();
await loadFaults();
await seedCustomers();
const app = buildServer();
await app.listen({ host: "0.0.0.0", port: config.port });
await waitForNode();
setInterval(() => loadFaults().catch(() => undefined), 5_000);
loop();
