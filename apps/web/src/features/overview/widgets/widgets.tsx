import { useQuery } from "@apollo/client/react";
import { Area, AreaChart, Bar, BarChart, CartesianGrid, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { Link } from "react-router";
import { useI18n } from "@/i18n";
import { useEnvironmentId, useSession } from "@/lib/session";
import { formatNumber, formatTime, relativeTime } from "@/lib/utils";
import { Hash, MetricCard, Sats } from "@/components/data/display";
import { ErrorState, LoadingState, StatusTag } from "@/components/ui/misc";
import { WIDGET_JOBS, WIDGET_NODES, WIDGET_OVERVIEW, WIDGET_RECONCILIATION, WIDGET_REORGS, WIDGET_TRANSACTIONS, WIDGET_VOLUME } from "./queries";

export interface WidgetProps {
  title: string;
  refreshMs?: number;
}

function useOverview(refreshMs?: number) {
  const environmentId = useEnvironmentId();
  return useQuery(WIDGET_OVERVIEW, { variables: { environmentId }, pollInterval: refreshMs });
}

function Frame({ title, children, action }: { title: string; children: React.ReactNode; action?: React.ReactNode }) {
  return (
    <div className="flex h-full min-h-0 flex-col overflow-hidden rounded-lg bg-surface">
      <div className="flex items-center justify-between gap-2 px-4 pb-1 pt-3">
        <h3 className="truncate text-[13px] font-semibold text-text">{title}</h3>
        {action}
      </div>
      <div className="min-h-0 flex-1 overflow-auto px-4 pb-3">{children}</div>
    </div>
  );
}

const tooltipStyle = { background: "var(--surface)", border: "1px solid var(--border)", borderRadius: 8, fontSize: 12, color: "var(--text)" };

export function ConfirmedBalanceWidget({ title, refreshMs }: WidgetProps) {
  const { data } = useOverview(refreshMs);
  const { t } = useI18n();
  return <MetricCard label={title} value={<Sats value={data?.overview.confirmedSats} />} hint={`${data?.overview.utxoCount ?? 0} ${t("wallets.utxos")}`} glow="green" />;
}

export function PendingBalanceWidget({ title, refreshMs }: WidgetProps) {
  const { data } = useOverview(refreshMs);
  return <MetricCard label={title} value={<Sats value={data?.overview.pendingSats} />} glow="amber" />;
}

export function HeightWidget({ title, refreshMs }: WidgetProps) {
  const { data } = useOverview(refreshMs);
  const { locale, t } = useI18n();
  return (
    <MetricCard
      label={title}
      value={formatNumber(data?.overview.tipHeight, locale)}
      hint={data?.overview.tipTime ? `${t("widgets.tip")} ${relativeTime(data.overview.tipTime, locale)}` : undefined}
      glow="blue"
    />
  );
}

export function MempoolWidget({ title, refreshMs }: WidgetProps) {
  const { data } = useOverview(refreshMs);
  const { locale, t } = useI18n();
  return <MetricCard label={title} value={formatNumber(data?.overview.mempoolSize, locale)} hint={t("widgets.pendingTx")} glow="violet" />;
}

export function OpenDiscrepanciesWidget({ title, refreshMs }: WidgetProps) {
  const { data } = useOverview(refreshMs);
  const { locale } = useI18n();
  const n = data?.overview.openDiscrepancies ?? 0;
  return (
    <Link to="/reconciliation" className="block h-full">
      <MetricCard label={title} value={formatNumber(n, locale)} glow={n > 0 ? "red" : "green"} />
    </Link>
  );
}

export function NodesWidget({ title, refreshMs }: WidgetProps) {
  const environmentId = useEnvironmentId();
  const { t, locale } = useI18n();
  const { data, loading, error, refetch } = useQuery(WIDGET_NODES, { variables: { environmentId }, pollInterval: refreshMs });
  return (
    <Frame title={title}>
      {error && !data ? <ErrorState onRetry={() => refetch()} /> : null}
      {loading && !data ? <LoadingState rows={2} /> : null}
      <ul className="flex flex-col divide-y divide-border">
        {data?.nodes.map((n) => (
          <li key={n.integration.id} className="flex items-center justify-between gap-3 py-2 text-[13px]">
            <div className="flex min-w-0 flex-col">
              <span className="font-medium text-text">
                {n.integration.name}
                {n.isReference ? <span className="ml-2 text-[11px] text-primary">{t("nodes.reference")}</span> : null}
              </span>
              <span className="text-[11px] text-text-muted">
                {t("nodes.height")} {formatNumber(n.latest?.height, locale)} · {n.latest?.rpcLatencyMs ?? "-"} ms · {n.latest?.peers ?? 0} {t("nodes.peers").toLowerCase()}
              </span>
            </div>
            <StatusTag status={n.latest?.reachable ? "healthy" : "unavailable"} />
          </li>
        ))}
      </ul>
    </Frame>
  );
}

export function RecentTransactionsWidget({ title, refreshMs }: WidgetProps) {
  const environmentId = useEnvironmentId();
  const { locale } = useI18n();
  const { data, loading } = useQuery(WIDGET_TRANSACTIONS, { variables: { environmentId }, pollInterval: refreshMs });
  return (
    <Frame title={title}>
      {loading && !data ? <LoadingState rows={3} /> : null}
      <ul className="flex flex-col divide-y divide-border">
        {data?.transactions.nodes.map((tx) => (
          <li key={tx.id} className="flex items-center justify-between gap-3 py-2 text-[12px]">
            <Link to={`/transactions/${tx.txid}`} className="min-w-0 hover:underline">
              <Hash value={tx.txid} copy={false} />
              <span className="block text-[11px] text-text-muted">{relativeTime(tx.firstSeenAt, locale)}</span>
            </Link>
            <div className="flex items-center gap-2">
              <Sats value={tx.totalOutSats} className="text-text" />
              <StatusTag status={tx.status} />
            </div>
          </li>
        ))}
      </ul>
    </Frame>
  );
}

export function VolumeWidget({ title, refreshMs }: WidgetProps) {
  const environmentId = useEnvironmentId();
  const { locale, t } = useI18n();
  const { data } = useQuery(WIDGET_VOLUME, { variables: { environmentId }, pollInterval: refreshMs ?? 60_000 });
  const points = (data?.transactionVolume ?? []).map((b) => ({ time: formatTime(b.bucket, locale).slice(0, 5), count: b.count }));
  return (
    <Frame title={title} action={<span className="text-[11px] text-text-muted">{t("widgets.hours24")}</span>}>
      <div className="h-full min-h-[140px]">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={points} margin={{ top: 8, right: 4, left: -24, bottom: 0 }}>
            <CartesianGrid stroke="var(--border)" vertical={false} />
            <XAxis dataKey="time" tick={{ fontSize: 11, fill: "var(--text-muted)" }} tickLine={false} axisLine={false} />
            <YAxis allowDecimals={false} tick={{ fontSize: 11, fill: "var(--text-muted)" }} tickLine={false} axisLine={false} />
            <Tooltip contentStyle={tooltipStyle} cursor={{ fill: "var(--surface-2)" }} />
            <Bar dataKey="count" fill="var(--chart-1)" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </Frame>
  );
}

export function ReconciliationSummaryWidget({ title, refreshMs }: WidgetProps) {
  const { data } = useOverview(refreshMs);
  const { t, locale } = useI18n();
  const run = data?.overview.lastReconciliation;
  const rate = run?.summary?.match_rate as number | null | undefined;
  return (
    <Frame title={title}>
      {!run ? (
        <p className="py-6 text-center text-[13px] text-text-muted">{t("widgets.noRuns")}</p>
      ) : (
        <Link to={`/reconciliation/runs/${run.id}`} className="flex flex-col gap-3 py-2">
          <span className="text-[32px] font-semibold leading-none">{rate === null || rate === undefined ? "-" : `${Math.round(rate * 100)}%`}</span>
          <span className="text-[12px] text-text-muted">{t("widgets.matchRate")}</span>
          <div className="flex flex-wrap items-center gap-2 text-[12px] text-text-secondary">
            <StatusTag status={run.status} />
            <StatusTag status={run.completeness} />
            <span>
              {t("widgets.lastRun")} {relativeTime(run.finishedAt, locale)}
            </span>
          </div>
        </Link>
      )}
    </Frame>
  );
}

export function ReconciliationHistoryWidget({ title, refreshMs }: WidgetProps) {
  const environmentId = useEnvironmentId();
  const { locale } = useI18n();
  const { data } = useQuery(WIDGET_RECONCILIATION, { variables: { environmentId }, pollInterval: refreshMs });
  const points = [...(data?.reconciliationRuns ?? [])]
    .reverse()
    .map((r) => ({ time: formatTime(r.insertedAt, locale).slice(0, 5), rate: Math.round(Number(r.summary?.match_rate ?? 0) * 100), discrepancies: Number(r.summary?.by_state?.discrepancy ?? 0) }));
  return (
    <Frame title={title}>
      <div className="h-full min-h-[140px]">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={points} margin={{ top: 8, right: 4, left: -24, bottom: 0 }}>
            <CartesianGrid stroke="var(--border)" vertical={false} />
            <XAxis dataKey="time" tick={{ fontSize: 11, fill: "var(--text-muted)" }} tickLine={false} axisLine={false} />
            <YAxis domain={[0, 100]} tick={{ fontSize: 11, fill: "var(--text-muted)" }} tickLine={false} axisLine={false} />
            <Tooltip contentStyle={tooltipStyle} />
            <Area type="monotone" dataKey="rate" stroke="var(--chart-4)" fill="var(--chart-4)" fillOpacity={0.15} />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </Frame>
  );
}

function ExperimentList({ items, empty }: { items: { id: string; scenarioName: string; status: string; startedAt?: string | null; finishedAt?: string | null }[]; empty: string }) {
  const { locale } = useI18n();
  if (!items.length) return <p className="py-6 text-center text-[13px] text-text-muted">{empty}</p>;
  return (
    <ul className="flex flex-col divide-y divide-border">
      {items.map((r) => (
        <li key={r.id} className="flex items-center justify-between gap-3 py-2 text-[12px]">
          <Link to={`/engineering/experiments/runs/${r.id}`} className="min-w-0 truncate font-medium text-text hover:underline">
            {r.scenarioName}
          </Link>
          <span className="flex items-center gap-2">
            <span className="text-[11px] text-text-muted">{relativeTime(r.finishedAt ?? r.startedAt, locale)}</span>
            <StatusTag status={r.status} />
          </span>
        </li>
      ))}
    </ul>
  );
}

export function ActiveExperimentsWidget({ title, refreshMs }: WidgetProps) {
  const { data } = useOverview(refreshMs);
  const { t } = useI18n();
  return (
    <Frame title={title}>
      <ExperimentList items={data?.overview.activeExperiments ?? []} empty={t("widgets.noExperiments")} />
    </Frame>
  );
}

export function ExperimentResultsWidget({ title, refreshMs }: WidgetProps) {
  const { data } = useOverview(refreshMs);
  const { t } = useI18n();
  return (
    <Frame title={title}>
      <ExperimentList items={data?.overview.recentExperiments ?? []} empty={t("experiments.empty")} />
    </Frame>
  );
}

export function JobsWidget({ title, refreshMs }: WidgetProps) {
  const { can } = useSession();
  const { data } = useQuery(WIDGET_JOBS, { pollInterval: refreshMs ?? 15_000, skip: !can("jobs.read") });
  const { t } = useI18n();
  const queues = new Map<string, Record<string, number>>();
  for (const s of data?.jobStats ?? []) queues.set(s.queue, { ...(queues.get(s.queue) ?? {}), [s.state]: s.count });
  return (
    <Frame title={title}>
      <table className="w-full text-[12px]">
        <thead className="text-left text-[11px] text-text-muted">
          <tr>
            <th className="py-1 font-medium">{t("jobs.queue")}</th>
            <th className="py-1 text-right font-medium">{t("status.available")}</th>
            <th className="py-1 text-right font-medium">{t("status.executing")}</th>
            <th className="py-1 text-right font-medium">{t("status.retryable")}</th>
          </tr>
        </thead>
        <tbody>
          {[...queues.entries()].map(([q, s]) => (
            <tr key={q} className="border-t border-border">
              <td className="py-1.5 font-medium text-text">{q}</td>
              <td className="py-1.5 text-right">{s.available ?? 0}</td>
              <td className="py-1.5 text-right">{s.executing ?? 0}</td>
              <td className="py-1.5 text-right">{s.retryable ?? 0}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </Frame>
  );
}

export function LatencyWidget({ title, refreshMs }: WidgetProps) {
  const environmentId = useEnvironmentId();
  const { locale, t } = useI18n();
  const overview = useOverview(refreshMs);
  const { data } = useQuery(WIDGET_NODES, { variables: { environmentId }, pollInterval: refreshMs });
  const series = new Map<string, Record<string, number | string>>();
  for (const n of data?.nodes ?? []) {
    for (const h of n.history) {
      const key = formatTime(h.observedAt, locale).slice(0, 5);
      series.set(key, { ...(series.get(key) ?? { time: key }), [n.integration.name]: h.rpcLatencyMs ?? 0 });
    }
  }
  const points = [...series.values()].reverse();
  const colors = ["var(--chart-1)", "var(--chart-2)", "var(--chart-3)"];
  return (
    <Frame
      title={title}
      action={
        <span className="text-[11px] text-text-muted">
          {t("widgets.lagBlocks")}: {overview.data?.overview.ingestionLagBlocks ?? "-"} {t("widgets.blocks")}
        </span>
      }
    >
      <div className="h-full min-h-[120px]">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={points} margin={{ top: 8, right: 4, left: -24, bottom: 0 }}>
            <CartesianGrid stroke="var(--border)" vertical={false} />
            <XAxis dataKey="time" tick={{ fontSize: 11, fill: "var(--text-muted)" }} tickLine={false} axisLine={false} />
            <YAxis tick={{ fontSize: 11, fill: "var(--text-muted)" }} tickLine={false} axisLine={false} unit="ms" />
            <Tooltip contentStyle={tooltipStyle} />
            {(data?.nodes ?? []).map((n, i) => (
              <Line key={n.integration.id} type="monotone" dataKey={n.integration.name} stroke={colors[i % colors.length]} dot={false} strokeWidth={2} />
            ))}
          </LineChart>
        </ResponsiveContainer>
      </div>
    </Frame>
  );
}

export function ReorgsWidget({ title, refreshMs }: WidgetProps) {
  const environmentId = useEnvironmentId();
  const { t, locale } = useI18n();
  const { data } = useQuery(WIDGET_REORGS, { variables: { environmentId }, pollInterval: refreshMs });
  const reorgs = data?.chainOverview.reorganizations ?? [];
  return (
    <Frame title={title}>
      {!reorgs.length ? <p className="py-6 text-center text-[13px] text-text-muted">{t("widgets.noReorgs")}</p> : null}
      <ul className="flex flex-col divide-y divide-border">
        {reorgs.map((r) => (
          <li key={r.id} className="flex items-center justify-between gap-3 py-2 text-[12px]">
            <span>
              {t("blockchain.depth")} <strong className="text-text">{String(r.payload?.depth ?? "?")}</strong> · {t("blockchain.ancestor")} {String(r.payload?.ancestor_height ?? "-")}
            </span>
            <span className="text-[11px] text-text-muted">{relativeTime(r.observedAt, locale)}</span>
          </li>
        ))}
      </ul>
    </Frame>
  );
}

export const WIDGETS: Record<string, React.ComponentType<WidgetProps>> = {
  "transactions.volume": VolumeWidget,
  "balance.confirmed": ConfirmedBalanceWidget,
  "balance.pending": PendingBalanceWidget,
  "blockchain.nodes": NodesWidget,
  "blockchain.height": HeightWidget,
  "blockchain.mempool": MempoolWidget,
  "transactions.recent": RecentTransactionsWidget,
  "reconciliation.summary": ReconciliationSummaryWidget,
  "reconciliation.open_discrepancies": OpenDiscrepanciesWidget,
  "reconciliation.history": ReconciliationHistoryWidget,
  "experiments.results": ExperimentResultsWidget,
  "experiments.active": ActiveExperimentsWidget,
  "jobs.status": JobsWidget,
  "ingestion.latency": LatencyWidget,
  "blockchain.reorganizations": ReorgsWidget,
};

export function WidgetError({ title }: { title: string }) {
  return (
    <div className="flex h-full items-center justify-center rounded-lg bg-surface p-4 text-[12px] text-text-muted">
      <ErrorState message={title} />
    </div>
  );
}
