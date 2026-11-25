function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required`);
  return value;
}

export const config = {
  port: Number(process.env.PORT ?? 8080),
  databaseUrl: required("DATABASE_URL"),
  rpcUrl: required("BITCOIN_RPC_URL"),
  rpcUser: required("BITCOIN_RPC_USER"),
  rpcPassword: required("BITCOIN_RPC_PASSWORD"),
  wallet: process.env.BITCOIN_WALLET ?? "demofintech",
  apiToken: required("API_TOKEN"),
  webhookUrl: process.env.WEBHOOK_URL ?? "",
  webhookSecret: process.env.WEBHOOK_SECRET ?? "",
  requiredConfirmations: Number(process.env.REQUIRED_CONFIRMATIONS ?? 3),
  faultModesAllowed: process.env.FAULT_MODES_ALLOWED === "true",
  syntheticCustomers: Number(process.env.SYNTHETIC_CUSTOMERS ?? 3),
  pollIntervalMs: Number(process.env.POLL_INTERVAL_MS ?? 3000),
};
