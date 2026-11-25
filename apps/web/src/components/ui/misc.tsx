import { useLayoutEffect, useRef, useState } from "react";
import { AlertTriangle } from "lucide-react";
import { useI18n } from "@/i18n";
import { cn } from "@/lib/utils";

export function Panel({ className, children, ...props }: React.HTMLAttributes<HTMLElement>) {
  return (
    <section className={cn("flex min-w-0 flex-col rounded-lg bg-surface", className)} {...props}>
      {children}
    </section>
  );
}

export function PanelHeader({ title, subtitle, actions, className }: { title: React.ReactNode; subtitle?: React.ReactNode; actions?: React.ReactNode; className?: string }) {
  return (
    <header className={cn("flex flex-wrap items-center gap-x-3 gap-y-2 px-5 pb-3 pt-4", className)}>
      <div className="flex min-w-0 flex-1 basis-[200px] flex-col gap-0.5">
        <h2 className="truncate text-base font-semibold text-text">{title}</h2>
        {subtitle ? <p className="text-xs text-text-muted">{subtitle}</p> : null}
      </div>
      {actions}
    </header>
  );
}

export function PageHeader({ title, subtitle, actions }: { title: React.ReactNode; subtitle?: React.ReactNode; actions?: React.ReactNode }) {
  return (
    <div data-page-header className="flex min-h-10 flex-wrap items-center gap-x-6 gap-y-3">
      <div className="flex min-w-0 flex-1 basis-[280px] flex-col items-start gap-2 sm:flex-row sm:flex-wrap sm:items-center sm:gap-4">
        <h1 className="text-2xl font-semibold leading-[1.35] text-text sm:text-[29px]">{title}</h1>
        {subtitle ? <p className="text-[13px] leading-6 text-text-secondary sm:border-l sm:border-border sm:pl-4">{subtitle}</p> : null}
      </div>
      {actions ? <div className="flex flex-wrap items-center gap-3">{actions}</div> : null}
    </div>
  );
}

export type Tone = "neutral" | "progress" | "violet" | "teal" | "done" | "pink" | "warning" | "info" | "success" | "danger" | "primary";

export function Tag({ tone = "neutral", children, dot = true, className }: { tone?: Tone; children: React.ReactNode; dot?: boolean; className?: string }) {
  return (
    <span
      className={cn(
        "tone inline-flex h-[21px] shrink-0 items-center gap-1.5 whitespace-nowrap rounded-full px-[7px] text-[11px] font-medium leading-[15px]",
        `tone-${tone}`,
        className,
      )}
    >
      {dot ? <span aria-hidden className="size-1.5 rounded-full bg-current" /> : null}
      {children}
    </span>
  );
}

const STATUS_TONES: Record<string, Tone> = {
  observed: "neutral",
  pending: "warning",
  confirmed: "success",
  unconfirmed: "warning",
  conflicted: "danger",
  replaced: "violet",
  unknown: "neutral",
  healthy: "success",
  unavailable: "danger",
  matched: "success",
  unmatched: "warning",
  discrepancy: "danger",
  ambiguous: "violet",
  resolved: "done",
  ignored: "neutral",
  open: "danger",
  investigating: "progress",
  queued: "neutral",
  running: "progress",
  completed: "success",
  incomplete: "warning",
  failed: "danger",
  created: "neutral",
  validating: "progress",
  provisioning: "progress",
  preparing: "progress",
  verifying: "progress",
  cleaning_up: "progress",
  passed: "success",
  inconclusive: "warning",
  aborted: "done",
  succeeded: "success",
  skipped: "neutral",
  applied: "success",
  firing: "danger",
  acknowledged: "progress",
  delivered: "success",
  failed_terminal: "danger",
  credited: "success",
  detected: "warning",
  reversed: "pink",
  cancelled: "neutral",
  reserved: "progress",
  settled: "success",
  released: "neutral",
  available: "success",
  executing: "progress",
  scheduled: "neutral",
  retryable: "warning",
  discarded: "danger",
  timed_out: "warning",
  source_unavailable: "warning",
  error: "danger",
  false: "danger",
  complete: "success",
};

export function StatusTag({ status, className }: { status: string | null | undefined; className?: string }) {
  const { tx } = useI18n();
  const s = status ?? "unknown";
  const label = tx(`status.${s}`);
  return (
    <Tag tone={STATUS_TONES[s] ?? "neutral"} className={className}>
      {label.startsWith("status.") ? s : label}
    </Tag>
  );
}

export function Kbd({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <kbd className={cn("inline-flex h-[22px] min-w-[22px] items-center justify-center whitespace-nowrap rounded bg-surface-3 px-1.5 font-sans text-[11px] font-medium text-text-secondary", className)}>
      {children}
    </kbd>
  );
}

export function Avatar({ name, size = 32, className }: { name: string; size?: number; className?: string }) {
  const initials = name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase())
    .join("");
  return (
    <span
      aria-hidden
      style={{ width: size, height: size, fontSize: size * 0.36 }}
      className={cn("inline-flex shrink-0 items-center justify-center rounded-full bg-primary-soft font-heading font-semibold text-primary-soft-foreground", className)}
    >
      {initials}
    </span>
  );
}

export function Segmented<T extends string>({
  value,
  onChange,
  options,
  label,
  className,
}: {
  value: T;
  onChange: (v: T) => void;
  options: { value: T; label: React.ReactNode }[];
  label: string;
  className?: string;
}) {
  const root = useRef<HTMLDivElement>(null);
  const [indicator, setIndicator] = useState<{ left: number; top: number; width: number; height: number } | null>(null);

  useLayoutEffect(() => {
    const element = root.current;
    if (!element) return;
    const measure = () => {
      const selected = element.querySelector<HTMLButtonElement>('[role="tab"][aria-selected="true"]');
      if (!selected) return setIndicator(null);
      setIndicator({ left: selected.offsetLeft, top: selected.offsetTop, width: selected.offsetWidth, height: selected.offsetHeight });
    };
    measure();
    if (typeof ResizeObserver === "undefined") return;
    const observer = new ResizeObserver(measure);
    observer.observe(element);
    return () => observer.disconnect();
  }, [value, options]);

  return (
    <div ref={root} role="tablist" aria-label={label} className={cn("relative isolate inline-flex items-center gap-1 rounded-lg bg-surface-2 p-[3px]", className)}>
      {indicator ? (
        <span
          aria-hidden="true"
          className="pointer-events-none absolute left-0 top-0 rounded-md bg-surface transition-[transform,width,height] duration-[220ms] ease-[var(--ease-out)] motion-reduce:transition-none"
          style={{ width: indicator.width, height: indicator.height, transform: `translate(${indicator.left}px, ${indicator.top}px)` }}
        />
      ) : null}
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          role="tab"
          aria-selected={value === o.value}
          onClick={() => onChange(o.value)}
          className={cn(
            "relative z-10 inline-flex h-7 items-center gap-1.5 whitespace-nowrap rounded-md px-2.5 text-xs font-medium transition-colors",
            value === o.value ? "text-text" : "text-text-secondary hover:text-text",
          )}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return <div aria-hidden className={cn("skeleton rounded-md bg-surface-2", className)} />;
}

export function LoadingState({ rows = 4, className }: { rows?: number; className?: string }) {
  const { t } = useI18n();
  return (
    <div role="status" aria-live="polite" className={cn("loading-surface flex flex-col gap-3 p-5", className)}>
      <span className="sr-only">{t("common.loading")}</span>
      {Array.from({ length: rows }, (_, i) => (
        <Skeleton key={i} className="h-5 w-full" />
      ))}
    </div>
  );
}

export function EmptyState({
  icon: Icon,
  title,
  description,
  action,
  className,
}: {
  icon: React.ComponentType<{ size?: number; className?: string }>;
  title: string;
  description?: string;
  action?: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("flex flex-col items-center justify-center gap-3 px-6 py-12 text-center", className)}>
      <span className="flex size-14 items-center justify-center rounded-2xl bg-primary-soft text-primary">
        <Icon size={28} />
      </span>
      <div className="flex max-w-sm flex-col gap-1">
        <p className="font-heading text-lg font-semibold text-text">{title}</p>
        {description ? <p className="text-sm text-text-muted">{description}</p> : null}
      </div>
      {action}
    </div>
  );
}

export function ErrorState({ message, onRetry }: { message?: string; onRetry?: () => void }) {
  const { t } = useI18n();
  return (
    <div role="alert" className="flex flex-col items-center gap-3 px-6 py-12 text-center">
      <AlertTriangle className="text-danger" size={24} />
      <p className="text-sm text-text-secondary">{message ?? t("common.error")}</p>
      {onRetry ? (
        <button type="button" onClick={onRetry} className="text-sm font-medium text-primary hover:underline">
          {t("common.retry")}
        </button>
      ) : null}
    </div>
  );
}

export function KV({ label, value, className }: { label: React.ReactNode; value: React.ReactNode; className?: string }) {
  return (
    <div className={cn("flex items-baseline justify-between gap-3 text-[13px]", className)}>
      <span className="shrink-0 text-text-muted">{label}</span>
      <span className="min-w-0 truncate text-right font-medium text-text">{value}</span>
    </div>
  );
}

export function SectionLabel({ children, className }: { children: React.ReactNode; className?: string }) {
  return <p className={cn("text-[11px] font-semibold uppercase tracking-wide text-text-muted", className)}>{children}</p>;
}

export function Notice({ tone = "info", children, className }: { tone?: "info" | "warning" | "danger" | "success"; children: React.ReactNode; className?: string }) {
  const tones = {
    info: "bg-info-soft text-info",
    warning: "bg-warning-soft text-warning",
    danger: "bg-danger-soft text-danger",
    success: "bg-success-soft text-success",
  };
  return <div className={cn("flex items-start gap-2.5 rounded-md px-4 py-3 text-[13px] leading-relaxed", tones[tone], className)}>{children}</div>;
}
