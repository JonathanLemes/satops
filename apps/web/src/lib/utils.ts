import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

const SATS_PER_BTC = 100_000_000;

export function formatSats(sats: number | null | undefined, locale: string): string {
  if (sats === null || sats === undefined) return "-";
  return `${new Intl.NumberFormat(locale).format(sats)} sats`;
}

export function formatBtc(sats: number | null | undefined, locale: string): string {
  if (sats === null || sats === undefined) return "-";
  const negative = sats < 0;
  const abs = Math.abs(sats);
  const whole = Math.floor(abs / SATS_PER_BTC);
  const frac = String(abs % SATS_PER_BTC).padStart(8, "0");
  const sep = new Intl.NumberFormat(locale).format(1.5).charAt(1);
  const wholeText = new Intl.NumberFormat(locale).format(whole);
  return `${negative ? "-" : ""}${wholeText}${sep}${frac} BTC`;
}

export function formatNumber(n: number | null | undefined, locale: string): string {
  if (n === null || n === undefined) return "-";
  return new Intl.NumberFormat(locale).format(n);
}

export function formatDateTime(value: string | null | undefined, locale: string): string {
  if (!value) return "-";
  return new Intl.DateTimeFormat(locale, { dateStyle: "short", timeStyle: "medium" }).format(new Date(value));
}

export function formatTime(value: string | null | undefined, locale: string): string {
  if (!value) return "-";
  return new Intl.DateTimeFormat(locale, { hour: "2-digit", minute: "2-digit", second: "2-digit" }).format(new Date(value));
}

export function relativeTime(value: string | null | undefined, locale: string, now = Date.now()): string {
  if (!value) return "-";
  const seconds = Math.round((new Date(value).getTime() - now) / 1000);
  const rtf = new Intl.RelativeTimeFormat(locale, { numeric: "auto" });
  const abs = Math.abs(seconds);
  if (abs < 60) return rtf.format(seconds, "second");
  if (abs < 3600) return rtf.format(Math.round(seconds / 60), "minute");
  if (abs < 86400) return rtf.format(Math.round(seconds / 3600), "hour");
  return rtf.format(Math.round(seconds / 86400), "day");
}

export function shortHash(hash: string | null | undefined, size = 8): string {
  if (!hash) return "-";
  return hash.length <= size * 2 + 1 ? hash : `${hash.slice(0, size)}…${hash.slice(-size)}`;
}

export function durationMs(ms: number | null | undefined): string {
  if (ms === null || ms === undefined) return "-";
  if (ms < 1000) return `${ms} ms`;
  if (ms < 60_000) return `${(ms / 1000).toFixed(1)} s`;
  return `${Math.floor(ms / 60_000)} min ${Math.round((ms % 60_000) / 1000)} s`;
}

export function downloadText(filename: string, content: string, type = "application/yaml") {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
