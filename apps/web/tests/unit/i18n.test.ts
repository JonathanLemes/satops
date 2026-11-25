import { describe, expect, it } from "vitest";
import { en } from "@/i18n/en";
import { ptBR } from "@/i18n/pt-BR";
import { translate } from "@/i18n";

function entries(obj: unknown, prefix = ""): [string, string][] {
  if (typeof obj !== "object" || obj === null) return [[prefix, String(obj)]];
  return Object.entries(obj).flatMap(([k, v]) => entries(v, prefix ? `${prefix}.${k}` : k));
}
const keys = (obj: unknown) => entries(obj).map(([k]) => k);
const EM_DASH = String.fromCharCode(0x2014);

describe("i18n", () => {
  it("Portuguese has exactly the same keys as English", () => {
    expect(keys(ptBR).sort()).toEqual(keys(en).sort());
  });

  it("no translation is empty or uses an em dash", () => {
    for (const dict of [en, ptBR]) {
      for (const [key, value] of entries(dict)) {
        expect(value.trim().length, key).toBeGreaterThan(0);
        expect(value.includes(EM_DASH), key).toBe(false);
      }
    }
  });

  it("interpolates variables, resolves dotted keys and falls back to English", () => {
    expect(translate("pt-BR", "integrations.imported", { count: 3 })).toBe("3 registros importados");
    expect(translate("pt-BR", "widgets.transactions.volume")).toBe("Volume de transações");
    expect(translate("pt-BR", "missing.key")).toBe("missing.key");
  });
});
