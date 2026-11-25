import { useQuery } from "@apollo/client/react";
import { AlertTriangle, ArrowLeft, Download } from "lucide-react";
import { useState } from "react";
import { Link, useParams } from "react-router";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { download } from "@/lib/api";
import { useSession } from "@/lib/session";
import { formatDateTime } from "@/lib/utils";
import { DataTable } from "@/components/data/data-table";
import { Hash, JsonView, MetricCard, Sats } from "@/components/data/display";
import { Button } from "@/components/ui/button";
import { ErrorState, LoadingState, Notice, PageHeader, Panel, PanelHeader, Segmented, StatusTag } from "@/components/ui/misc";
import { Sheet } from "@/components/ui/overlay";
import { useKindLabel } from "./reconciliation-page";

const RUN = graphql(`
  query ReconciliationRun($id: ID!, $state: String) {
    reconciliationRun(id: $id) {
      id
      status
      completeness
      trigger
      policyName
      policyVersion
      policy
      referenceHeight
      referenceHash
      sources
      summary
      error
      startedAt
      finishedAt
      items(state: $state, limit: 1000) {
        id
        matchKey
        state
        discrepancyKind
        reason
        records
        amountSats
        txid
        vout
      }
    }
  }
`);

interface SourceMeta {
  name: string;
  kind: string;
  status: string;
  required: boolean;
  records: number;
  balances: number;
  watermark?: string | null;
  error?: string | null;
}

export default function RunDetailPage() {
  const { id = "" } = useParams();
  const { t, locale } = useI18n();
  const { can } = useSession();
  const [state, setState] = useState<string>("all");
  const { data, loading, error, refetch } = useQuery(RUN, { variables: { id, state: state === "all" ? null : state }, pollInterval: 4000 });
  const [inspect, setInspect] = useState<{ reason: string; records: unknown } | null>(null);
  const kindLabel = useKindLabel();
  const run = data?.reconciliationRun;

  if (loading && !data) return <LoadingState rows={8} />;
  if ((error && !data) || !run) return <ErrorState onRetry={() => refetch()} />;
  const byState = (run.summary?.by_state ?? {}) as Record<string, number>;
  const sources = (run.sources ?? []) as SourceMeta[];

  return (
    <div className="flex flex-col gap-5">
      <Link to="/reconciliation?tab=runs" className="inline-flex items-center gap-2 text-sm text-text-secondary hover:text-text">
        <ArrowLeft size={16} /> {t("reconciliation.runs")}
      </Link>
      <PageHeader
        title={`${t("reconciliation.title")} ${formatDateTime(run.startedAt, locale)}`}
        subtitle={`${run.policyName} v${run.policyVersion} · ${run.trigger}`}
        actions={
          <>
            <StatusTag status={run.status} />
            <StatusTag status={run.completeness} />
            {can("reconciliation.export") ? (
              <Button onClick={() => download(`/api/reports/reconciliation/${run.id}`, `reconciliation-${run.id.slice(0, 8)}.json`)}>
                <Download /> {t("reconciliation.exportJson")}
              </Button>
            ) : null}
          </>
        }
      />
      {run.status === "incomplete" ? (
        <Notice tone="warning">
          <AlertTriangle size={16} className="mt-0.5 shrink-0" />
          {t("reconciliation.incompleteWarning")}
        </Notice>
      ) : null}
      {run.error ? <Notice tone="danger">{run.error}</Notice> : null}
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-5">
        <MetricCard label={t("reconciliation.matchRate")} value={run.summary?.match_rate === null || run.summary?.match_rate === undefined ? "-" : `${Math.round(Number(run.summary.match_rate) * 100)}%`} glow="green" />
        <MetricCard label={t("status.matched")} value={byState.matched ?? 0} glow="green" />
        <MetricCard label={t("status.pending")} value={byState.pending ?? 0} glow="amber" />
        <MetricCard label={t("status.discrepancy")} value={byState.discrepancy ?? 0} glow="red" />
        <MetricCard label={t("reconciliation.reference")} value={run.referenceHeight ?? "-"} hint={<Hash value={run.referenceHash} copy={false} />} glow="blue" />
      </div>
      <Panel>
        <PanelHeader title={t("reconciliation.sources")} />
        <DataTable
          rows={sources}
          rowKey={(s) => s.name}
          columns={[
            { key: "name", header: t("reconciliation.source"), primary: true, cell: (s) => `${s.name}${s.required ? " *" : ""}` },
            { key: "kind", header: t("common.kind"), cell: (s) => s.kind },
            { key: "status", header: t("common.status"), cell: (s) => <StatusTag status={s.status === "ok" ? "healthy" : "unavailable"} /> },
            { key: "records", header: t("reconciliation.records"), align: "right", cell: (s) => s.records },
            { key: "watermark", header: t("reconciliation.watermark"), cell: (s) => (s.watermark ? formatDateTime(s.watermark, locale) : "-") },
            { key: "error", header: t("integrations.lastError"), cell: (s) => s.error ?? "-" },
          ]}
        />
      </Panel>
      <Panel>
        <PanelHeader
          title={t("reconciliation.items")}
          actions={
            <Segmented
              label={t("common.filter")}
              value={state}
              onChange={setState}
              options={["all", "discrepancy", "pending", "ambiguous", "matched"].map((s) => ({ value: s, label: s === "all" ? t("common.all") : t(`status.${s}` as "status.matched") }))}
            />
          }
        />
        <DataTable
          rows={run.items}
          rowKey={(i) => i.id}
          onRowClick={(i) => setInspect({ reason: i.reason, records: i.records })}
          columns={[
            { key: "state", header: t("common.status"), cell: (i) => <StatusTag status={i.state} /> },
            { key: "kind", header: t("discrepancies.kind"), cell: (i) => (i.discrepancyKind ? kindLabel(i.discrepancyKind) : "-") },
            { key: "key", header: t("reconciliation.matchKey"), cell: (i) => <span className="font-mono text-[11px]">{i.matchKey.split("|")[1]?.slice(0, 28)}</span> },
            { key: "source", header: t("reconciliation.source"), cell: (i) => i.matchKey.split("|")[0] },
            { key: "amount", header: t("common.amount"), align: "right", cell: (i) => <Sats value={i.amountSats} /> },
            { key: "reason", header: t("common.reason"), cell: (i) => <span className="line-clamp-2 max-w-md">{i.reason}</span> },
          ]}
          pageSize={30}
        />
      </Panel>
      <Sheet open={!!inspect} onOpenChange={(o) => !o && setInspect(null)} title={t("discrepancies.evidence")} description={inspect?.reason}>
        <JsonView value={inspect?.records} maxHeight={800} />
      </Sheet>
    </div>
  );
}
