import { createHmac, timingSafeEqual } from "node:crypto";

export function sign(secret: string, timestamp: number, body: string): string {
  const mac = createHmac("sha256", secret).update(`${timestamp}.${body}`).digest("hex");
  return `t=${timestamp},v1=${mac}`;
}

export function verify(secret: string, header: string, body: string, toleranceSeconds = 300, now = Date.now()): boolean {
  const parts = Object.fromEntries(header.split(",").map((p) => p.split("=", 2) as [string, string]));
  const ts = Number(parts.t);
  if (!Number.isFinite(ts) || Math.abs(now / 1000 - ts) > toleranceSeconds || !parts.v1) return false;
  const expected = Buffer.from(sign(secret, ts, body).split("v1=")[1] ?? "", "hex");
  const given = Buffer.from(parts.v1, "hex");
  return expected.length === given.length && timingSafeEqual(expected, given);
}
