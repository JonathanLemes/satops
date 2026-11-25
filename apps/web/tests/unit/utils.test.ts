import { describe, expect, it } from "vitest";
import { formatBtc, formatSats, shortHash } from "@/lib/utils";

describe("money formatting", () => {
  it("never uses floating point for BTC amounts", () => {
    expect(formatBtc(1, "en")).toBe("0.00000001 BTC");
    expect(formatBtc(2_099_999_997_690_000, "en")).toBe("20,999,999.97690000 BTC");
    expect(formatBtc(150_000_000, "pt-BR")).toBe("1,50000000 BTC");
    expect(formatBtc(-5, "en")).toBe("-0.00000005 BTC");
  });

  it("formats satoshis with the locale separators", () => {
    expect(formatSats(1_500_000, "en")).toBe("1,500,000 sats");
    expect(formatSats(1_500_000, "pt-BR")).toBe("1.500.000 sats");
    expect(formatSats(null, "en")).toBe("-");
  });

  it("shortens hashes", () => {
    expect(shortHash("a".repeat(64), 4)).toBe("aaaa…aaaa");
  });
});
