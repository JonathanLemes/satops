import { config } from "./config.ts";
export { btcToSats, satsToBtc } from "./money.ts";

export class RpcError extends Error {
  code: number;
  constructor(code: number, message: string) {
    super(message);
    this.code = code;
  }
}

export async function rpc<T>(method: string, params: unknown[] = [], wallet?: string): Promise<T> {
  const url = wallet ? `${config.rpcUrl}/wallet/${encodeURIComponent(wallet)}` : config.rpcUrl;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Basic ${Buffer.from(`${config.rpcUser}:${config.rpcPassword}`).toString("base64")}`,
    },
    body: JSON.stringify({ jsonrpc: "1.0", id: "demo-fintech", method, params }),
    signal: AbortSignal.timeout(10_000),
  });
  const text = await res.text();
  const body = JSON.parse(text.replace(/("amount"|"fee"|"value"):\s*(-?\d+(?:\.\d+)?)/g, '$1:"$2"')) as {
    result: T;
    error: { code: number; message: string } | null;
  };
  if (body.error) throw new RpcError(body.error.code, body.error.message);
  return body.result;
}

export async function ensureWallet(): Promise<void> {
  try {
    await rpc("createwallet", [config.wallet]);
  } catch (error) {
    if (!(error instanceof RpcError)) throw error;
    if (error.code === -4) {
      try {
        await rpc("loadwallet", [config.wallet]);
      } catch (inner) {
        if (!(inner instanceof RpcError && inner.code === -35)) throw inner;
      }
    } else if (error.code !== -35) {
      throw error;
    }
  }
}
