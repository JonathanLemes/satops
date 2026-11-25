import { Check, Copy } from "lucide-react";
import { useState } from "react";
import { useI18n } from "@/i18n";
import { cn, formatBtc, formatSats, shortHash } from "@/lib/utils";

export function Sats({
  value,
  className,
  signed,
}: {
  value: number | null | undefined;
  className?: string;
  signed?: boolean;
}) {
  const { locale } = useI18n();
  const prefix = signed && value && value > 0 ? "+" : "";
  return (
    <span className={cn("whitespace-nowrap tabular-nums", className)} title={formatSats(value, locale)}>
      {prefix}
      {formatBtc(value, locale)}
    </span>
  );
}

export function Hash({
  value,
  size = 8,
  className,
  copy = true,
}: {
  value: string | null | undefined;
  size?: number;
  className?: string;
  copy?: boolean;
}) {
  const { t } = useI18n();
  const [copied, setCopied] = useState(false);
  if (!value) return <span className="text-text-muted">-</span>;
  return (
    <span className={cn("inline-flex items-center gap-1 font-mono text-[12px]", className)} title={value}>
      {shortHash(value, size)}
      {copy ? (
        <button
          type="button"
          aria-label={copied ? t("common.copied") : t("common.copy")}
          className="rounded p-0.5 text-text-muted hover:bg-surface-2 hover:text-text"
          onClick={(e) => {
            e.stopPropagation();
            navigator.clipboard?.writeText(value).then(() => {
              setCopied(true);
              setTimeout(() => setCopied(false), 1200);
            });
          }}
        >
          {copied ? <Check size={12} /> : <Copy size={12} />}
        </button>
      ) : null}
    </span>
  );
}

export function MetricCard({
  label,
  value,
  hint,
  glow,
  className,
}: {
  label: React.ReactNode;
  value: React.ReactNode;
  hint?: React.ReactNode;
  glow?: "blue" | "green" | "amber" | "violet" | "red";
  className?: string;
}) {
  return (
    <div className={cn("metric-card h-full", className)} data-glow={glow}>
      <div className="relative flex min-w-0 flex-col gap-1">
        <span className="metric-label">{label}</span>
        <span className="metric-value truncate">{value}</span>
        {hint ? <span className="text-[11px] text-text-muted">{hint}</span> : null}
      </div>
    </div>
  );
}

export interface TimelineItem {
  id: string;
  title: React.ReactNode;
  time?: string | null;
  description?: React.ReactNode;
  tone?: "default" | "success" | "warning" | "danger" | "primary";
  meta?: React.ReactNode;
}

export function Timeline({ items, className }: { items: TimelineItem[]; className?: string }) {
  const { locale } = useI18n();
  const dot = {
    default: "bg-border-strong",
    success: "bg-success",
    warning: "bg-warning",
    danger: "bg-danger",
    primary: "bg-primary",
  };
  return (
    <ol className={cn("relative flex flex-col", className)}>
      {items.map((item, i) => (
        <li key={item.id} className="relative flex gap-4 pb-5 last:pb-0">
          {i < items.length - 1 ? (
            <span aria-hidden className="absolute left-[5px] top-4 h-full w-px bg-border" />
          ) : null}
          <span
            aria-hidden
            className={cn(
              "relative mt-1.5 size-[11px] shrink-0 rounded-full ring-4 ring-surface",
              dot[item.tone ?? "default"],
            )}
          />
          <div className="flex min-w-0 flex-1 flex-col gap-1">
            <div className="flex flex-wrap items-baseline justify-between gap-x-3">
              <span className="text-[13px] font-medium text-text">{item.title}</span>
              {item.time ? (
                <time className="text-[11px] text-text-muted" dateTime={item.time}>
                  {new Intl.DateTimeFormat(locale, { dateStyle: "short", timeStyle: "medium" }).format(
                    new Date(item.time),
                  )}
                </time>
              ) : null}
            </div>
            {item.description ? (
              <div className="text-xs leading-relaxed text-text-secondary">{item.description}</div>
            ) : null}
            {item.meta}
          </div>
        </li>
      ))}
    </ol>
  );
}

export function JsonView({
  value,
  className,
  maxHeight = 320,
}: {
  value: unknown;
  className?: string;
  maxHeight?: number;
}) {
  return (
    <pre
      className={cn(
        "overflow-auto rounded-md bg-surface-2 p-3 font-mono text-[11.5px] leading-relaxed text-text-secondary",
        className,
      )}
      style={{ maxHeight }}
    >
      {JSON.stringify(value, null, 2)}
    </pre>
  );
}

export function EventInspector({
  event,
}: {
  event: {
    eventType: string;
    seq: number;
    aggregateType: string;
    aggregateId: string;
    correlationId: string;
    causationId?: string | null;
    observedAt: string;
    schemaVersion: number;
    payload?: unknown;
  };
}) {
  const { t } = useI18n();
  return (
    <div className="flex flex-col gap-3">
      <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 text-[12px]">
        <dt className="text-text-muted">{t("blockchain.eventType")}</dt>
        <dd className="font-mono">
          {event.eventType} v{event.schemaVersion} #{event.seq}
        </dd>
        <dt className="text-text-muted">{t("blockchain.aggregate")}</dt>
        <dd>
          {event.aggregateType} <Hash value={event.aggregateId} />
        </dd>
        <dt className="text-text-muted">{t("blockchain.correlation")}</dt>
        <dd>
          <Hash value={event.correlationId} />
        </dd>
        <dt className="text-text-muted">{t("blockchain.causation")}</dt>
        <dd>
          <Hash value={event.causationId} />
        </dd>
      </dl>
      <JsonView value={event.payload} />
    </div>
  );
}
