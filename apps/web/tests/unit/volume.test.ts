import { describe, expect, it } from "vitest";
import { hourlySeries } from "@/features/overview/widgets/widgets";

describe("hourlySeries", () => {
  it("fills the last 24 hours with zeros where there were no transactions", () => {
    const now = Date.UTC(2026, 10, 25, 12, 30);
    const series = hourlySeries([{ bucket: "2026-11-25T10:00:00Z", count: 3, valueSats: 1000 }], now);
    expect(series).toHaveLength(24);
    expect(series.at(-1)!.hour).toBe(Date.UTC(2026, 10, 25, 12));
    expect(series.find((p) => p.hour === Date.UTC(2026, 10, 25, 10))).toMatchObject({ count: 3, valueSats: 1000 });
    expect(series.reduce((s, p) => s + p.count, 0)).toBe(3);
  });
});
