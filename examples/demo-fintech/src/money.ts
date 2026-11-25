export function btcToSats(value: string | number): number {
  const [whole, frac = ""] = String(value).replace("-", "").split(".");
  const sats = Number(whole) * 100_000_000 + Number((frac + "00000000").slice(0, 8));
  return String(value).startsWith("-") ? -sats : sats;
}

export function satsToBtc(sats: number): string {
  const whole = Math.floor(sats / 100_000_000);
  const frac = String(sats % 100_000_000).padStart(8, "0");
  return `${whole}.${frac}`;
}
