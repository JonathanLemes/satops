import { useMutation, useQuery } from "@apollo/client/react";
import { FileCode2, Play, Plus } from "lucide-react";
import { useState } from "react";
import { Link, useNavigate } from "react-router";
import { toast } from "sonner";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { useEnvironmentId, useSession } from "@/lib/session";
import { relativeTime } from "@/lib/utils";
import { DataTable } from "@/components/data/data-table";
import { Button } from "@/components/ui/button";
import { Field, Input } from "@/components/ui/input";
import { Notice, PageHeader, Panel, PanelHeader, Segmented, StatusTag, Tag } from "@/components/ui/misc";
import { Dialog } from "@/components/ui/overlay";

const EXPERIMENTS = graphql(`
  query ExperimentRuns($environmentId: ID!) {
    scenarios {
      id
      name
      version
      title
      description
      guarantee
      requiredCapabilities
      versions
    }
    runtimeCapabilities(environmentId: $environmentId)
    experimentActions {
      name
      idempotency
      capabilities
    }
    experimentRuns(environmentId: $environmentId, limit: 50) {
      id
      scenarioName
      scenarioVersion
      status
      statusReason
      seed
      startedAt
      finishedAt
      insertedAt
    }
  }
`);

const START = graphql(`
  mutation StartExperiment($environmentId: ID!, $scenarioId: ID!, $seed: Int) {
    startExperiment(environmentId: $environmentId, scenarioId: $scenarioId, seed: $seed) {
      id
    }
  }
`);

export default function ExperimentsPage() {
  const { t, locale } = useI18n();
  const environmentId = useEnvironmentId();
  const { can } = useSession();
  const navigate = useNavigate();
  const { data, loading, refetch } = useQuery(EXPERIMENTS, { variables: { environmentId } });
  const [start, startState] = useMutation(START);
  const [tab, setTab] = useState<"scenarios" | "runs" | "actions">("scenarios");
  const [starting, setStarting] = useState<{ id: string; title: string } | null>(null);
  const [seed, setSeed] = useState("");
  const caps = new Set(data?.runtimeCapabilities ?? []);

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t("experiments.title")}
        subtitle={t("experiments.subtitle")}
        actions={
          can("config.apply") ? (
            <Link to="/engineering/configuration/new?kind=Experiment">
              <Button>
                <Plus /> {t("experiments.builder")}
              </Button>
            </Link>
          ) : null
        }
      />
      <Notice tone="info">{t("experiments.builderHint")}</Notice>
      <Panel>
        <PanelHeader
          title={
            <Segmented
              label={t("experiments.title")}
              value={tab}
              onChange={setTab}
              options={[
                { value: "scenarios", label: t("experiments.scenarios") },
                { value: "runs", label: t("experiments.runs") },
                { value: "actions", label: t("experiments.actions") },
              ]}
            />
          }
        />
        {tab === "scenarios" ? (
          <ul className="flex flex-col divide-y divide-border border-t border-border">
            {data?.scenarios.map((s) => {
              const missing = s.requiredCapabilities.filter((c) => !caps.has(c));
              return (
                <li key={s.id} className="flex flex-col gap-3 px-5 py-4 lg:flex-row lg:items-center">
                  <div className="flex min-w-0 flex-1 flex-col gap-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="font-semibold">{s.title}</span>
                      <Tag tone="neutral" dot={false}>
                        {s.name} v{s.version}
                      </Tag>
                      {missing.length ? <Tag tone="warning">{t("experiments.missingCapabilities")}: {missing.join(", ")}</Tag> : null}
                    </div>
                    <p className="text-[13px] text-text-secondary">{s.description}</p>
                    <p className="text-xs text-text-muted">
                      {t("experiments.guarantee")}: {s.guarantee}
                    </p>
                  </div>
                  <div className="flex gap-2">
                    <Link to={`/engineering/configuration/Experiment/${s.name}`}>
                      <Button size="md" variant="ghost" aria-label={t("integrations.editAsCode")}>
                        <FileCode2 />
                      </Button>
                    </Link>
                    {can("experiment.run") ? (
                      <Button size="md" variant="primary" onClick={() => setStarting({ id: s.id, title: s.title })}>
                        <Play /> {t("experiments.start")}
                      </Button>
                    ) : null}
                  </div>
                </li>
              );
            })}
          </ul>
        ) : null}
        {tab === "runs" ? (
          <DataTable
            rows={data?.experimentRuns}
            loading={loading}
            rowKey={(r) => r.id}
            onRowClick={(r) => navigate(`/engineering/experiments/runs/${r.id}`)}
            empty={{ title: t("experiments.empty") }}
            columns={[
              { key: "scenario", header: t("experiments.scenarios"), primary: true, cell: (r) => `${r.scenarioName} v${r.scenarioVersion}` },
              { key: "status", header: t("common.status"), cell: (r) => <StatusTag status={r.status} /> },
              { key: "reason", header: t("experiments.reason"), cell: (r) => <span className="line-clamp-1 max-w-md">{r.statusReason ?? ""}</span> },
              { key: "seed", header: t("experiments.seed"), cell: (r) => <span className="font-mono text-xs">{r.seed}</span> },
              { key: "started", header: t("reconciliation.started"), cell: (r) => relativeTime(r.startedAt ?? r.insertedAt, locale), sortValue: (r) => r.insertedAt },
            ]}
            pageSize={25}
          />
        ) : null}
        {tab === "actions" ? (
          <DataTable
            rows={data?.experimentActions}
            rowKey={(a) => a.name}
            columns={[
              { key: "name", header: t("experiments.action"), primary: true, cell: (a) => <span className="font-mono text-xs">{a.name}</span> },
              { key: "idem", header: t("experiments.idempotency"), cell: (a) => <Tag tone={a.idempotency === "unsafe" ? "warning" : "teal"} dot={false}>{a.idempotency}</Tag> },
              {
                key: "caps",
                header: t("experiments.capabilities"),
                cell: (a) =>
                  a.capabilities.map((c) => (
                    <Tag key={c} tone={caps.has(c) ? "success" : "neutral"} dot={false} className="mr-1">
                      {c}
                    </Tag>
                  )),
              },
            ]}
          />
        ) : null}
      </Panel>
      <p className="text-xs text-text-muted">{t("experiments.reproducibility")}</p>
      <Dialog open={!!starting} onOpenChange={(o) => !o && setStarting(null)} title={`${t("experiments.start")}: ${starting?.title ?? ""}`}>
        <Field label={`${t("experiments.seed")} (${t("common.optional")})`}>
          {(id) => <Input id={id} type="number" value={seed} onChange={(e) => setSeed(e.target.value)} />}
        </Field>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={() => setStarting(null)}>
            {t("common.cancel")}
          </Button>
          <Button
            variant="primary"
            loading={startState.loading}
            onClick={async () => {
              try {
                const r = await start({ variables: { environmentId, scenarioId: starting!.id, seed: seed ? Number(seed) : null } });
                toast.success(t("experiments.started"));
                setStarting(null);
                refetch();
                if (r.data?.startExperiment) navigate(`/engineering/experiments/runs/${r.data.startExperiment.id}`);
              } catch (e) {
                toast.error(e instanceof Error ? e.message : t("common.error"));
              }
            }}
          >
            <Play /> {t("experiments.start")}
          </Button>
        </div>
      </Dialog>
    </div>
  );
}
