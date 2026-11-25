import { useMutation, useQuery } from "@apollo/client/react";
import { CheckCircle2, Play } from "lucide-react";
import { useState } from "react";
import { useNavigate, useSearchParams } from "react-router";
import { toast } from "sonner";
import { useI18n } from "@/i18n";
import { useEnvironmentId, useSession } from "@/lib/session";
import { formatDateTime, relativeTime } from "@/lib/utils";
import { DataTable } from "@/components/data/data-table";
import { Hash, Sats } from "@/components/data/display";
import { Button } from "@/components/ui/button";
import { PageHeader, Panel, PanelHeader, Segmented, StatusTag, Tag } from "@/components/ui/misc";
import { DISCREPANCIES, RUN_RECONCILIATION, RUNS } from "./queries";

export function useKindLabel() {
  const { tx } = useI18n();
  return (kind: string) => {
    const label = tx(`discrepancies.kinds.${kind}`);
    return label.startsWith("discrepancies.") ? kind : label;
  };
}

export default function ReconciliationPage() {
  const { t, locale } = useI18n();
  const environmentId = useEnvironmentId();
  const { can } = useSession();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const tab = (params.get("tab") as "discrepancies" | "runs" | null) ?? "discrepancies";
  const [states, setStates] = useState<"active" | "all">("active");
  const runs = useQuery(RUNS, { variables: { environmentId } });
  const discrepancies = useQuery(DISCREPANCIES, { variables: { environmentId, states: states === "active" ? ["open", "investigating"] : null } });
  const [run, runState] = useMutation(RUN_RECONCILIATION);
  const kindLabel = useKindLabel();

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t("reconciliation.title")}
        subtitle={t("reconciliation.subtitle")}
        actions={
          can("reconciliation.run") ? (
            <Button
              variant="primary"
              loading={runState.loading}
              onClick={async () => {
                const r = await run({ variables: { environmentId } });
                toast.success(t("reconciliation.runQueued"));
                runs.refetch();
                if (r.data?.runReconciliation) navigate(`/reconciliation/runs/${r.data.runReconciliation.id}`);
              }}
            >
              <Play /> {t("reconciliation.run")}
            </Button>
          ) : null
        }
      />
      <Panel>
        <PanelHeader
          title={
            <Segmented
              label={t("reconciliation.title")}
              value={tab}
              onChange={(v) => setParams({ tab: v })}
              options={[
                { value: "discrepancies", label: t("discrepancies.title") },
                { value: "runs", label: t("reconciliation.runs") },
              ]}
            />
          }
          actions={
            tab === "discrepancies" ? (
              <Segmented
                label={t("common.filter")}
                value={states}
                onChange={setStates}
                options={[
                  { value: "active", label: t("status.open") },
                  { value: "all", label: t("common.all") },
                ]}
              />
            ) : null
          }
        />
        {tab === "discrepancies" ? (
          <DataTable
            rows={discrepancies.data?.discrepancies}
            loading={discrepancies.loading}
            error={discrepancies.error}
            onRetry={() => discrepancies.refetch()}
            rowKey={(d) => d.id}
            onRowClick={(d) => navigate(`/reconciliation/discrepancies/${d.id}`)}
            empty={{ title: t("discrepancies.empty"), description: t("discrepancies.emptyHint") }}
            columns={[
              { key: "kind", header: t("discrepancies.kind"), primary: true, cell: (d) => kindLabel(d.kind), sortValue: (d) => d.kind },
              { key: "severity", header: t("discrepancies.severity"), cell: (d) => <Tag tone={d.severity === "critical" ? "danger" : d.severity === "high" ? "warning" : "neutral"}>{d.severity}</Tag> },
              { key: "source", header: t("reconciliation.source"), cell: (d) => d.source ?? "-" },
              { key: "tx", header: t("transactions.txid"), cell: (d) => <Hash value={d.txid} copy={false} /> },
              { key: "amount", header: t("common.amount"), align: "right", cell: (d) => <Sats value={d.amountSats} /> },
              { key: "state", header: t("common.status"), cell: (d) => <StatusTag status={d.state} /> },
              { key: "seen", header: t("discrepancies.occurrences"), align: "right", cell: (d) => d.occurrences, sortValue: (d) => d.occurrences },
              { key: "updated", header: t("common.updated"), cell: (d) => relativeTime(d.updatedAt, locale), sortValue: (d) => d.updatedAt },
            ]}
            pageSize={25}
          />
        ) : (
          <DataTable
            rows={runs.data?.reconciliationRuns}
            loading={runs.loading}
            error={runs.error}
            rowKey={(r) => r.id}
            onRowClick={(r) => navigate(`/reconciliation/runs/${r.id}`)}
            empty={{ title: t("reconciliation.empty"), description: t("reconciliation.emptyHint") }}
            columns={[
              { key: "started", header: t("reconciliation.started"), primary: true, cell: (r) => formatDateTime(r.startedAt ?? r.insertedAt, locale), sortValue: (r) => r.insertedAt },
              { key: "status", header: t("common.status"), cell: (r) => <StatusTag status={r.status} /> },
              { key: "completeness", header: t("reconciliation.completeness"), cell: (r) => <StatusTag status={r.completeness} /> },
              {
                key: "rate",
                header: t("reconciliation.matchRate"),
                align: "right",
                cell: (r) => (r.summary?.match_rate === null || r.summary?.match_rate === undefined ? "-" : `${Math.round(Number(r.summary.match_rate) * 100)}%`),
              },
              { key: "disc", header: t("status.discrepancy"), align: "right", cell: (r) => Number(r.summary?.by_state?.discrepancy ?? 0) },
              { key: "ref", header: t("reconciliation.reference"), align: "right", cell: (r) => r.referenceHeight ?? "-" },
              { key: "trigger", header: t("reconciliation.trigger"), cell: (r) => r.trigger },
              { key: "policy", header: t("reconciliation.policy"), cell: (r) => `${r.policyName} v${r.policyVersion}` },
            ]}
            pageSize={25}
          />
        )}
      </Panel>
      {tab === "discrepancies" && discrepancies.data?.discrepancies.length === 0 ? (
        <p className="flex items-center gap-2 text-xs text-text-muted">
          <CheckCircle2 size={14} /> {t("discrepancies.emptyHint")}
        </p>
      ) : null}
    </div>
  );
}
