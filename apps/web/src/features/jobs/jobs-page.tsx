import { useMutation, useQuery } from "@apollo/client/react";
import { RotateCcw } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { useSession } from "@/lib/session";
import { formatDateTime, relativeTime } from "@/lib/utils";
import { DataTable } from "@/components/data/data-table";
import { JsonView } from "@/components/data/display";
import { Button } from "@/components/ui/button";
import { Field, Input, Select } from "@/components/ui/input";
import { Notice, PageHeader, Panel, PanelHeader, StatusTag } from "@/components/ui/misc";
import { Dialog, Sheet } from "@/components/ui/overlay";

const JOBS = graphql(`
  query Jobs($state: String) {
    jobStats {
      queue
      state
      count
    }
    eventConsumers {
      consumer
      lastSeq
      lag
      updatedAt
    }
    jobs(state: $state, limit: 100) {
      id
      queue
      worker
      state
      attempt
      maxAttempts
      errors
      insertedAt
      attemptedAt
      completedAt
    }
  }
`);

const REPLAY = graphql(`
  mutation ReplayEvents($consumer: String!, $fromSeq: Int!) {
    replayEvents(consumer: $consumer, fromSeq: $fromSeq)
  }
`);

export default function JobsPage() {
  const { t, locale } = useI18n();
  const { can } = useSession();
  const [state, setState] = useState("");
  const { data, loading, refetch } = useQuery(JOBS, { variables: { state: state || null }, pollInterval: 10_000 });
  const [replay] = useMutation(REPLAY);
  const [replaying, setReplaying] = useState<string | null>(null);
  const [fromSeq, setFromSeq] = useState(1);
  const [job, setJob] = useState<unknown>(null);
  const queues = new Map<string, Record<string, number>>();
  for (const s of data?.jobStats ?? []) queues.set(s.queue, { ...(queues.get(s.queue) ?? {}), [s.state]: s.count });
  const states = ["available", "scheduled", "executing", "retryable", "completed", "discarded", "cancelled"];

  return (
    <div className="flex flex-col gap-5">
      <PageHeader title={t("jobs.title")} subtitle={t("jobs.subtitle")} />
      <Panel>
        <PanelHeader title={t("jobs.queues")} />
        <DataTable
          rows={[...queues.entries()].map(([queue, s]) => ({ queue, s }))}
          rowKey={(r) => r.queue}
          columns={[
            { key: "queue", header: t("jobs.queue"), primary: true, cell: (r) => r.queue },
            ...states.map((st) => ({ key: st, header: t(`status.${st}` as "status.available"), align: "right" as const, cell: (r: { s: Record<string, number> }) => r.s[st] ?? 0 })),
          ]}
        />
      </Panel>
      <Panel>
        <PanelHeader title={t("jobs.consumers")} />
        <div className="px-5 pb-2">
          <Notice tone="info">{t("jobs.replayHint")}</Notice>
        </div>
        <DataTable
          rows={data?.eventConsumers}
          rowKey={(c) => c.consumer}
          columns={[
            { key: "consumer", header: t("common.name"), primary: true, cell: (c) => <span className="font-mono text-xs">{c.consumer}</span> },
            { key: "seq", header: t("jobs.lastSeq"), align: "right", cell: (c) => c.lastSeq },
            { key: "lag", header: t("jobs.lag"), align: "right", cell: (c) => c.lag },
            { key: "updated", header: t("common.updated"), cell: (c) => relativeTime(c.updatedAt, locale) },
            {
              key: "replay",
              header: "",
              align: "right",
              cell: (c) =>
                can("config.apply") ? (
                  <Button size="sm" onClick={() => setReplaying(c.consumer)}>
                    <RotateCcw /> {t("jobs.replay")}
                  </Button>
                ) : null,
            },
          ]}
        />
      </Panel>
      <Panel>
        <PanelHeader
          title={t("jobs.recent")}
          actions={
            <Select aria-label={t("jobs.state")} value={state} onChange={(e) => setState(e.target.value)} className="w-44">
              <option value="">{t("common.all")}</option>
              {states.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </Select>
          }
        />
        <DataTable
          rows={data?.jobs}
          loading={loading}
          rowKey={(j) => j.id}
          onRowClick={(j) => setJob(j)}
          columns={[
            { key: "id", header: "#", cell: (j) => j.id },
            { key: "worker", header: t("jobs.worker"), primary: true, cell: (j) => <span className="font-mono text-[11px]">{j.worker.replace("SatOps.", "")}</span> },
            { key: "queue", header: t("jobs.queue"), cell: (j) => j.queue },
            { key: "state", header: t("jobs.state"), cell: (j) => <StatusTag status={j.state} /> },
            { key: "attempt", header: t("jobs.attempt"), align: "right", cell: (j) => `${j.attempt}/${j.maxAttempts}` },
            { key: "time", header: t("common.time"), cell: (j) => formatDateTime(j.attemptedAt ?? j.insertedAt, locale) },
          ]}
          pageSize={25}
        />
      </Panel>
      <Sheet open={!!job} onOpenChange={(o) => !o && setJob(null)} title={t("jobs.worker")}>
        <JsonView value={job} maxHeight={800} />
      </Sheet>
      <Dialog open={!!replaying} onOpenChange={(o) => !o && setReplaying(null)} title={`${t("jobs.replay")}: ${replaying ?? ""}`} description={t("jobs.replayHint")}>
        <Field label="seq">{(id) => <Input id={id} type="number" min={1} value={fromSeq} onChange={(e) => setFromSeq(Number(e.target.value))} />}</Field>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={() => setReplaying(null)}>
            {t("common.cancel")}
          </Button>
          <Button
            variant="primary"
            onClick={async () => {
              await replay({ variables: { consumer: replaying!, fromSeq } });
              toast.success(t("jobs.replayQueued"));
              setReplaying(null);
              refetch();
            }}
          >
            {t("common.confirm")}
          </Button>
        </div>
      </Dialog>
    </div>
  );
}
