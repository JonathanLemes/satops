import { useMutation, useQuery } from "@apollo/client/react";
import { ArrowLeft, Lightbulb, Link2, Play } from "lucide-react";
import { useState } from "react";
import { Link, useParams } from "react-router";
import { toast } from "sonner";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { useSession } from "@/lib/session";
import { formatDateTime } from "@/lib/utils";
import { Hash, JsonView, Sats, Timeline } from "@/components/data/display";
import { Button } from "@/components/ui/button";
import { Field, Textarea } from "@/components/ui/input";
import { ErrorState, KV, LoadingState, Notice, PageHeader, Panel, PanelHeader, StatusTag, Tag } from "@/components/ui/misc";
import { ConfirmDialog, Dialog } from "@/components/ui/overlay";
import { RUN_RECONCILIATION } from "./queries";
import { useKindLabel } from "./reconciliation-page";

const DISCREPANCY = graphql(`
  query Discrepancy($id: ID!) {
    discrepancy(id: $id) {
      id
      environmentId
      kind
      state
      severity
      source
      matchKey
      txid
      vout
      amountSats
      reason
      evidence
      occurrences
      firstRunId
      lastRunId
      resolution
      resolvedAt
      insertedAt
      updatedAt
      suggestion
      notes {
        id
        authorEmail
        kind
        body
        data
        insertedAt
      }
    }
  }
`);

const TRANSITION = graphql(`
  mutation TransitionDiscrepancy($id: ID!, $state: String!, $note: String) {
    transitionDiscrepancy(id: $id, state: $state, note: $note) {
      id
      state
    }
  }
`);

const NOTE = graphql(`
  mutation AddDiscrepancyNote($id: ID!, $body: String!, $kind: String, $data: JSON) {
    addDiscrepancyNote(id: $id, body: $body, kind: $kind, data: $data) {
      id
    }
  }
`);

export default function DiscrepancyPage() {
  const { id = "" } = useParams();
  const { t, locale } = useI18n();
  const { can } = useSession();
  const kindLabel = useKindLabel();
  const { data, loading, error, refetch } = useQuery(DISCREPANCY, { variables: { id } });
  const [transition] = useMutation(TRANSITION);
  const [addNote, noteState] = useMutation(NOTE);
  const [rerun] = useMutation(RUN_RECONCILIATION);
  const [note, setNote] = useState("");
  const [ask, setAsk] = useState<null | "resolved" | "ignored">(null);
  const [linking, setLinking] = useState(false);
  const [link, setLink] = useState("");
  const d = data?.discrepancy;

  if (loading && !data) return <LoadingState rows={8} />;
  if ((error && !data) || !d) return <ErrorState onRetry={() => refetch()} />;
  const canResolve = can("discrepancy.resolve");
  const active = d.state === "open" || d.state === "investigating";

  const move = async (state: string, n?: string) => {
    try {
      await transition({ variables: { id: d.id, state, note: n } });
      await refetch();
      toast.success(t("common.saved"));
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("common.error"));
    }
  };

  return (
    <div className="flex flex-col gap-5">
      <Link to="/reconciliation" className="inline-flex items-center gap-2 text-sm text-text-secondary hover:text-text">
        <ArrowLeft size={16} /> {t("discrepancies.title")}
      </Link>
      <PageHeader
        title={kindLabel(d.kind)}
        subtitle={d.reason}
        actions={
          <>
            <Tag tone={d.severity === "critical" ? "danger" : "warning"}>{d.severity}</Tag>
            <StatusTag status={d.state} />
          </>
        }
      />
      <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_380px]">
        <div className="flex min-w-0 flex-col gap-5">
          <Panel>
            <PanelHeader title={t("discrepancies.evidence")} subtitle={`${t("reconciliation.source")}: ${d.source ?? "-"}`} />
            <div className="px-5 pb-5">
              <JsonView value={d.evidence} maxHeight={480} />
            </div>
          </Panel>
          <Panel className="p-5">
            <h2 className="mb-4 text-base font-semibold">{t("discrepancies.notes")}</h2>
            <Timeline
              items={[
                { id: "created", title: kindLabel(d.kind), time: d.insertedAt, description: d.reason, tone: "danger" as const },
                ...d.notes.map((n) => ({
                  id: n.id,
                  title: `${n.authorEmail ?? "system"} · ${n.kind}`,
                  time: n.insertedAt,
                  description: n.body,
                  tone: n.kind === "link" ? ("primary" as const) : ("default" as const),
                })),
                ...(d.resolvedAt ? [{ id: "resolved", title: t(`status.${d.state}` as "status.resolved"), time: d.resolvedAt, description: d.resolution, tone: "success" as const }] : []),
              ]}
            />
            {canResolve ? (
              <form
                className="mt-5 flex flex-col gap-3"
                onSubmit={async (e) => {
                  e.preventDefault();
                  if (!note.trim()) return;
                  await addNote({ variables: { id: d.id, body: note.trim(), kind: "note" } });
                  setNote("");
                  refetch();
                }}
              >
                <Field label={t("discrepancies.addNote")}>{(fid) => <Textarea id={fid} value={note} onChange={(e) => setNote(e.target.value)} />}</Field>
                <div className="flex justify-end">
                  <Button type="submit" loading={noteState.loading} disabled={!note.trim()}>
                    {t("discrepancies.addNote")}
                  </Button>
                </div>
              </form>
            ) : null}
          </Panel>
        </div>
        <div className="flex flex-col gap-5">
          <Panel className="gap-2 p-5">
            <KV label={t("transactions.txid")} value={d.txid ? <Link to={`/transactions/${d.txid}`}><Hash value={d.txid} copy={false} /></Link> : "-"} />
            <KV label="vout" value={d.vout ?? "-"} />
            <KV label={t("common.amount")} value={<Sats value={d.amountSats} />} />
            <KV label={t("discrepancies.occurrences")} value={d.occurrences} />
            <KV label={t("common.created")} value={formatDateTime(d.insertedAt, locale)} />
            <KV label={t("reconciliation.runs")} value={<Link className="text-primary hover:underline" to={`/reconciliation/runs/${d.lastRunId}`}>{d.lastRunId.slice(0, 8)}</Link>} />
            {d.txid && d.vout !== null && d.vout !== undefined ? (
              <Link className="mt-2 text-[13px] font-medium text-primary hover:underline" to={`/audit?operation=${encodeURIComponent(`deposit:${d.txid}:${d.vout}`)}`}>
                {t("discrepancies.openTimeline")}
              </Link>
            ) : null}
          </Panel>
          <Notice tone="info">
            <Lightbulb size={16} className="mt-0.5 shrink-0" />
            <span>
              <strong className="block">{t("discrepancies.suggestion")}</strong>
              {d.suggestion}
            </span>
          </Notice>
          {canResolve ? (
            <Panel className="gap-2 p-5">
              {active && d.state === "open" ? <Button onClick={() => move("investigating")}>{t("discrepancies.investigate")}</Button> : null}
              {active ? (
                <Button variant="primary" onClick={() => setAsk("resolved")}>
                  {t("discrepancies.resolve")}
                </Button>
              ) : null}
              {active ? (
                <Button variant="ghost" onClick={() => setAsk("ignored")}>
                  {t("discrepancies.ignore")}
                </Button>
              ) : (
                <Button onClick={() => move("open")}>{t("discrepancies.reopen")}</Button>
              )}
              <Button variant="ghost" onClick={() => setLinking(true)}>
                <Link2 /> {t("discrepancies.linkRecords")}
              </Button>
              {can("reconciliation.run") ? (
                <Button
                  variant="ghost"
                  onClick={async () => {
                    await rerun({ variables: { environmentId: d.environmentId } });
                    toast.success(t("reconciliation.runQueued"));
                  }}
                >
                  <Play /> {t("discrepancies.rerun")}
                </Button>
              ) : null}
            </Panel>
          ) : null}
        </div>
      </div>
      <ConfirmDialog
        open={!!ask}
        onOpenChange={(o) => !o && setAsk(null)}
        title={ask === "ignored" ? t("discrepancies.ignore") : t("discrepancies.resolve")}
        requireReason={ask === "ignored" ? t("discrepancies.justification") : t("common.note")}
        onConfirm={(reason) => move(ask!, reason)}
      />
      <Dialog open={linking} onOpenChange={setLinking} title={t("discrepancies.linkRecords")} description={t("discrepancies.linkHint")}>
        <Textarea value={link} onChange={(e) => setLink(e.target.value)} />
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={() => setLinking(false)}>
            {t("common.cancel")}
          </Button>
          <Button
            variant="primary"
            disabled={!link.trim()}
            onClick={async () => {
              await addNote({ variables: { id: d.id, body: link.trim(), kind: "link", data: { linkedRecord: link.trim() } } });
              setLink("");
              setLinking(false);
              refetch();
            }}
          >
            {t("common.save")}
          </Button>
        </div>
      </Dialog>
    </div>
  );
}
