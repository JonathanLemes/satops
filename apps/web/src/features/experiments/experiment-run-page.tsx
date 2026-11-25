import { useMutation, useQuery } from "@apollo/client/react";
import { ArrowLeft, Download, Square } from "lucide-react";
import { useState } from "react";
import { Link, useParams } from "react-router";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { download } from "@/lib/api";
import { useSession } from "@/lib/session";
import { cn, durationMs, formatDateTime } from "@/lib/utils";
import { JsonView, MetricCard } from "@/components/data/display";
import { Button } from "@/components/ui/button";
import { ErrorState, LoadingState, Notice, PageHeader, Panel, PanelHeader, StatusTag, Tag } from "@/components/ui/misc";
import { ConfirmDialog, Sheet } from "@/components/ui/overlay";

const RUN = graphql(`
  query ExperimentRun($id: ID!) {
    experimentRun(id: $id) {
      id
      scenarioName
      scenarioVersion
      status
      statusReason
      cleanupStatus
      seed
      startedAt
      finishedAt
      insertedAt
      report
      steps {
        id
        position
        stepKey
        phase
        action
        params
        status
        attempts
        maxAttempts
        timeoutMs
        checkpoint
        result
        failureReason
        startedAt
        finishedAt
      }
      assertions {
        id
        position
        type
        params
        outcome
        expected
        actual
        message
        attempts
      }
    }
  }
`);

const ABORT = graphql(`
  mutation AbortExperiment($id: ID!) {
    abortExperiment(id: $id) {
      id
      status
    }
  }
`);

const TERMINAL = ["passed", "failed", "inconclusive", "aborted"];

export default function ExperimentRunPage() {
  const { id = "" } = useParams();
  const { t, locale } = useI18n();
  const { can } = useSession();
  const { data, loading, error, refetch } = useQuery(RUN, { variables: { id }, pollInterval: 3000 });
  const [abort] = useMutation(ABORT);
  const [aborting, setAborting] = useState(false);
  const [inspect, setInspect] = useState<{ title: string; value: unknown } | null>(null);
  const run = data?.experimentRun;

  if (loading && !data) return <LoadingState rows={8} />;
  if ((error && !data) || !run) return <ErrorState onRetry={() => refetch()} />;
  const done = run.steps.filter((s) => ["succeeded", "failed", "skipped", "unknown"].includes(s.status)).length;
  const pct = run.steps.length ? Math.round((done / run.steps.length) * 100) : 0;
  const terminal = TERMINAL.includes(run.status);
  const elapsed = run.startedAt ? new Date(run.finishedAt ?? Date.now()).getTime() - new Date(run.startedAt).getTime() : null;

  return (
    <div className="flex flex-col gap-5">
      <Link to="/engineering/experiments" className="inline-flex items-center gap-2 text-sm text-text-secondary hover:text-text">
        <ArrowLeft size={16} /> {t("experiments.title")}
      </Link>
      <PageHeader
        title={`${run.scenarioName} v${run.scenarioVersion}`}
        subtitle={`${t("experiments.seed")} ${run.seed} · ${formatDateTime(run.startedAt ?? run.insertedAt, locale)}`}
        actions={
          <>
            <StatusTag status={run.status} />
            {terminal ? (
              <Button onClick={() => download(`/api/reports/experiments/${run.id}`, `experiment-${run.scenarioName}-${run.id.slice(0, 8)}.json`)}>
                <Download /> {t("experiments.downloadReport")}
              </Button>
            ) : can("experiment.run") ? (
              <Button variant="danger" onClick={() => setAborting(true)}>
                <Square /> {t("experiments.abort")}
              </Button>
            ) : null}
          </>
        }
      />
      {run.statusReason ? <Notice tone={run.status === "passed" ? "success" : run.status === "failed" ? "danger" : "warning"}>{run.statusReason}</Notice> : null}
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <MetricCard label={t("experiments.progress")} value={`${pct}%`} hint={`${done}/${run.steps.length} ${t("experiments.steps").toLowerCase()}`} glow="blue" />
        <MetricCard label={t("experiments.duration")} value={durationMs(elapsed)} glow="violet" />
        <MetricCard label={t("experiments.assertions")} value={`${run.assertions.filter((a) => a.outcome === "passed").length}/${run.assertions.length}`} glow="green" />
        <MetricCard label={t("experiments.cleanup")} value={<StatusTag status={run.cleanupStatus === "completed" ? "completed" : run.cleanupStatus === "failed" ? "failed" : "pending"} />} glow="amber" />
      </div>
      <div className="h-1.5 overflow-hidden rounded-full bg-surface-3" role="progressbar" aria-valuenow={pct} aria-valuemin={0} aria-valuemax={100} aria-label={t("experiments.progress")}>
        <div className="h-full rounded-full bg-primary transition-[width] duration-500" style={{ width: `${pct}%` }} />
      </div>
      <Panel>
        <PanelHeader title={t("experiments.steps")} />
        <ol className="flex flex-col divide-y divide-border border-t border-border">
          {run.steps.map((s) => (
            <li key={s.id}>
              <button
                type="button"
                className="flex w-full flex-wrap items-center gap-3 px-5 py-3 text-left hover:bg-surface-2"
                onClick={() => setInspect({ title: s.stepKey, value: { params: s.params, result: s.result, checkpoint: s.checkpoint, failure: s.failureReason } })}
              >
                <span className={cn("w-6 text-right font-mono text-xs text-text-muted")}>{s.position + 1}</span>
                <Tag tone="neutral" dot={false}>
                  {s.phase}
                </Tag>
                <span className="min-w-0 flex-1">
                  <span className="block text-[13px] font-medium">{s.stepKey}</span>
                  <span className="block font-mono text-[11px] text-text-muted">{s.action}</span>
                  {s.failureReason ? <span className="block text-xs text-danger">{s.failureReason}</span> : null}
                </span>
                <span className="text-xs text-text-muted">
                  {s.attempts}/{s.maxAttempts} · {s.startedAt && s.finishedAt ? durationMs(new Date(s.finishedAt).getTime() - new Date(s.startedAt).getTime()) : "-"}
                </span>
                <StatusTag status={s.status} />
              </button>
            </li>
          ))}
        </ol>
      </Panel>
      <Panel>
        <PanelHeader title={t("experiments.assertions")} />
        <ul className="flex flex-col divide-y divide-border border-t border-border">
          {run.assertions.length === 0 ? <li className="px-5 py-4 text-[13px] text-text-muted">{t("common.noResults")}</li> : null}
          {run.assertions.map((a) => (
            <li key={a.id} className="flex flex-wrap items-center gap-3 px-5 py-3">
              <span className="min-w-0 flex-1">
                <span className="block font-mono text-[12px]">{a.type}</span>
                <span className="block text-xs text-text-muted">{a.message}</span>
              </span>
              <span className="text-xs text-text-secondary">
                {t("experiments.expected")}: {JSON.stringify(a.expected?.value ?? a.expected)} · {t("experiments.actual")}: {JSON.stringify(a.actual?.value ?? a.actual)}
              </span>
              <StatusTag status={a.outcome === "passed" ? "passed" : a.outcome} />
            </li>
          ))}
        </ul>
      </Panel>
      {run.report ? (
        <Panel>
          <PanelHeader title={t("experiments.report")} />
          <div className="px-5 pb-5">
            <JsonView value={run.report} maxHeight={500} />
          </div>
        </Panel>
      ) : null}
      <Sheet open={!!inspect} onOpenChange={(o) => !o && setInspect(null)} title={inspect?.title ?? ""}>
        <JsonView value={inspect?.value} maxHeight={800} />
      </Sheet>
      <ConfirmDialog
        open={aborting}
        onOpenChange={setAborting}
        title={t("experiments.abort")}
        description={t("experiments.abortConfirm")}
        danger
        onConfirm={async () => {
          await abort({ variables: { id: run.id } });
          refetch();
        }}
      />
    </div>
  );
}
