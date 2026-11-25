import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { en, type Dictionary } from "./en";
import { ptBR } from "./pt-BR";

export type Locale = "en" | "pt-BR";
export const LOCALES: { value: Locale; label: string; short: string }[] = [
  { value: "en", label: "English", short: "EN" },
  { value: "pt-BR", label: "Português (Brasil)", short: "PT" },
];

const dictionaries: Record<Locale, Dictionary> = { en, "pt-BR": ptBR };
const KEY = "satops.locale";

type Join<K, P> = K extends string ? (P extends string ? `${K}.${P}` : never) : never;
type Paths<T> = T extends string
  ? never
  : { [K in keyof T & string]: T[K] extends string ? K : Join<K, Paths<T[K]>> }[keyof T & string];
export type TranslationKey = Paths<Dictionary>;

export function translate(locale: Locale, key: string, vars?: Record<string, string | number>): string {
  const value = lookup(dictionaries[locale], key.split(".")) ?? lookup(en, key.split("."));
  const text = typeof value === "string" ? value : key;
  return vars ? text.replace(/\{\{(\w+)\}\}/g, (_, name: string) => String(vars[name] ?? "")) : text;
}

function lookup(node: unknown, parts: string[]): unknown {
  if (parts.length === 0) return node;
  if (!node || typeof node !== "object") return undefined;
  for (let i = parts.length; i >= 1; i--) {
    const key = parts.slice(0, i).join(".");
    if (key in (node as Record<string, unknown>)) {
      const found = lookup((node as Record<string, unknown>)[key], parts.slice(i));
      if (found !== undefined) return found;
    }
  }
  return undefined;
}

export function detectLocale(): Locale {
  try {
    const stored = localStorage.getItem(KEY);
    if (stored === "en" || stored === "pt-BR") return stored;
  } catch {
    return "en";
  }
  return typeof navigator !== "undefined" && navigator.language?.toLowerCase().startsWith("pt") ? "pt-BR" : "en";
}

interface I18nValue {
  locale: Locale;
  setLocale: (l: Locale) => void;
  t: (key: TranslationKey, vars?: Record<string, string | number>) => string;
  tx: (key: string, vars?: Record<string, string | number>) => string;
}

const I18nContext = createContext<I18nValue>({
  locale: "en",
  setLocale: () => {},
  t: (key) => translate("en", key),
  tx: (key) => translate("en", key),
});

export function I18nProvider({ children, initial }: { children: ReactNode; initial?: Locale }) {
  const [locale, setLocaleState] = useState<Locale>(initial ?? detectLocale);

  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);

  const setLocale = useCallback((l: Locale) => {
    setLocaleState(l);
    try {
      localStorage.setItem(KEY, l);
    } catch {
      return;
    }
  }, []);

  const value = useMemo<I18nValue>(
    () => ({
      locale,
      setLocale,
      t: (key, vars) => translate(locale, key, vars),
      tx: (key, vars) => translate(locale, key, vars),
    }),
    [locale, setLocale],
  );

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export const useI18n = () => useContext(I18nContext);
