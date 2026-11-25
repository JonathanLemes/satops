import { useMutation, useQuery } from "@apollo/client/react";
import { FileCode2, KeyRound, Plug, Plus, Trash2, Upload } from "lucide-react";
import { useRef, useState } from "react";
import { Link } from "react-router";
import { toast } from "sonner";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { upload } from "@/lib/api";
import { useEnvironmentId, useSession } from "@/lib/session";
import { formatDateTime, relativeTime } from "@/lib/utils";
import { DataTable } from "@/components/data/data-table";
import { JsonView } from "@/components/data/display";
import { Button } from "@/components/ui/button";
import { Field, Input, Select } from "@/components/ui/input";
import { KV, Notice, PageHeader, Panel, StatusTag, Tag } from "@/components/ui/misc";
import { ConfirmDialog, Sheet } from "@/components/ui/overlay";

const INTEGRATIONS = graphql(`
  query Integrations($environmentId: ID!) {
    integrations(environmentId: $environmentId) {
      id
      name
      kind
      status
      enabled
      config
      secretRef
      health
      capabilities
      checkpoint
      lastSyncAt
      lastError
      lockVersion
      updatedAt
      errors {
        message
        occurredAt
      }
    }
    secretNames(environmentId: $environmentId)
    integrationKinds
  }
`);

const TEST = graphql(`
  mutation TestIntegration($id: ID!) {
    testIntegration(id: $id) {
      ok
      status
      details
      error
    }
  }
`);

const SAVE = graphql(`
  mutation SaveIntegration($environmentId: ID!, $input: IntegrationInput!) {
    saveIntegration(environmentId: $environmentId, input: $input) {
      id
    }
  }
`);

const DELETE = graphql(`
  mutation DeleteIntegration($id: ID!) {
    deleteIntegration(id: $id)
  }
`);

const PUT_SECRET = graphql(`
  mutation PutSecret($environmentId: ID!, $name: String!, $value: String!) {
    putSecret(environmentId: $environmentId, name: $name, value: $value)
  }
`);

const FIELDS: Record<
  string,
  {
    key: string;
    label:
      | "integrations.host"
      | "integrations.port"
      | "integrations.zmqEndpoint"
      | "integrations.baseUrl"
      | "integrations.url"
      | "integrations.timeout"
      | "integrations.interval"
      | "integrations.priority";
    type?: "number";
  }[]
> = {
  bitcoin_core: [
    { key: "host", label: "integrations.host" },
    { key: "port", label: "integrations.port", type: "number" },
    { key: "zmqEndpoint", label: "integrations.zmqEndpoint" },
    { key: "reconcileIntervalMs", label: "integrations.interval", type: "number" },
    { key: "timeoutMs", label: "integrations.timeout", type: "number" },
    { key: "priority", label: "integrations.priority", type: "number" },
  ],
  demo_fintech: [
    { key: "baseUrl", label: "integrations.baseUrl" },
    { key: "timeoutMs", label: "integrations.timeout", type: "number" },
  ],
  generic_rest: [
    { key: "baseUrl", label: "integrations.baseUrl" },
    { key: "timeoutMs", label: "integrations.timeout", type: "number" },
  ],
  webhook_destination: [{ key: "url", label: "integrations.url" }],
};

const CONFIG_KIND: Record<string, string> = { bitcoin_core: "BitcoinIntegration" };

export default function IntegrationsPage() {
  const { t, locale } = useI18n();
  const environmentId = useEnvironmentId();
  const { can, environment } = useSession();
  const { data, loading, error, refetch } = useQuery(INTEGRATIONS, { variables: { environmentId } });
  const [test, testState] = useMutation(TEST);
  const [save, saveState] = useMutation(SAVE);
  const [remove] = useMutation(DELETE);
  const [putSecret] = useMutation(PUT_SECRET);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [editing, setEditing] = useState<null | {
    name: string;
    kind: string;
    secretRef: string;
    enabled: boolean;
    config: Record<string, unknown>;
    lockVersion?: number;
  }>(null);
  const [secretOpen, setSecretOpen] = useState(false);
  const [secret, setSecret] = useState({ name: "", value: "" });
  const [toDelete, setToDelete] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const selected = data?.integrations.find((i) => i.id === selectedId);

  const runTest = async (id: string) => {
    const r = await test({ variables: { id } });
    const res = r.data?.testIntegration;
    if (res?.ok) toast.success(t("integrations.testOk"));
    else toast.error(`${t("integrations.testFailed")}: ${res?.error ?? ""}`);
    refetch();
  };

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t("integrations.title")}
        subtitle={t("integrations.subtitle")}
        actions={
          <>
            {can("secret.manage") ? (
              <Button onClick={() => setSecretOpen(true)}>
                <KeyRound /> {t("integrations.secrets")}
              </Button>
            ) : null}
            {can("integration.manage") ? (
              <Button
                variant="primary"
                onClick={() => setEditing({ name: "", kind: "demo_fintech", secretRef: "", enabled: true, config: {} })}
              >
                <Plus /> {t("integrations.add")}
              </Button>
            ) : null}
          </>
        }
      />
      <Panel>
        <DataTable
          rows={data?.integrations}
          loading={loading}
          error={error}
          onRetry={() => refetch()}
          rowKey={(i) => i.id}
          onRowClick={(i) => setSelectedId(i.id)}
          empty={{ title: t("common.noResults") }}
          columns={[
            { key: "name", header: t("common.name"), primary: true, cell: (i) => i.name },
            {
              key: "kind",
              header: t("common.kind"),
              cell: (i) => (
                <Tag tone="neutral" dot={false}>
                  {i.kind}
                </Tag>
              ),
            },
            {
              key: "status",
              header: t("common.status"),
              cell: (i) => <StatusTag status={i.enabled ? i.status : "skipped"} />,
            },
            { key: "sync", header: t("integrations.lastSync"), cell: (i) => relativeTime(i.lastSyncAt, locale) },
            {
              key: "error",
              header: t("integrations.lastError"),
              cell: (i) => <span className="line-clamp-1 max-w-xs text-danger">{i.lastError ?? ""}</span>,
            },
            {
              key: "test",
              header: "",
              align: "right",
              cell: (i) => (
                <Button
                  size="sm"
                  onClick={(e) => {
                    e.stopPropagation();
                    runTest(i.id);
                  }}
                >
                  <Plug /> {t("integrations.test")}
                </Button>
              ),
            },
          ]}
        />
      </Panel>
      <Sheet
        open={!!selected}
        onOpenChange={(o) => !o && setSelectedId(null)}
        title={selected?.name ?? ""}
        description={selected?.kind}
        width={640}
      >
        {selected ? (
          <div className="flex flex-col gap-5">
            <div className="flex flex-wrap gap-2">
              <Button variant="primary" loading={testState.loading} onClick={() => runTest(selected.id)}>
                <Plug /> {t("integrations.test")}
              </Button>
              {can("integration.manage") ? (
                <Button
                  onClick={() =>
                    setEditing({
                      name: selected.name,
                      kind: selected.kind,
                      secretRef: selected.secretRef ?? "",
                      enabled: selected.enabled,
                      config: selected.config ?? {},
                      lockVersion: selected.lockVersion,
                    })
                  }
                >
                  {t("common.edit")}
                </Button>
              ) : null}
              <Link
                to={`/engineering/configuration/${CONFIG_KIND[selected.kind] ?? "FinancialIntegration"}/${selected.name}`}
              >
                <Button>
                  <FileCode2 /> {t("integrations.editAsCode")}
                </Button>
              </Link>
              {selected.kind === "csv_import" && can("integration.manage") ? (
                <>
                  <Button onClick={() => fileRef.current?.click()}>
                    <Upload /> {t("integrations.uploadCsv")}
                  </Button>
                  <input
                    ref={fileRef}
                    type="file"
                    accept=".csv,text/csv"
                    className="hidden"
                    onChange={async (e) => {
                      const f = e.target.files?.[0];
                      e.target.value = "";
                      if (!f) return;
                      try {
                        const r = await upload<{ imported: number }>(`/api/imports/csv/${selected.id}`, f);
                        toast.success(t("integrations.imported", { count: r.imported }));
                      } catch (err) {
                        toast.error(err instanceof Error ? err.message : t("common.error"));
                      }
                    }}
                  />
                </>
              ) : null}
              {can("integration.manage") ? (
                <Button variant="ghost" onClick={() => setToDelete(selected.id)}>
                  <Trash2 /> {t("common.delete")}
                </Button>
              ) : null}
            </div>
            {selected.kind === "csv_import" ? <Notice tone="info">{t("integrations.csvHint")}</Notice> : null}
            {selected.capabilities.includes("webhooks.inbound") ? (
              <KV
                label={t("integrations.webhookUrl")}
                value={
                  <span className="font-mono text-xs">{`/api/webhooks/${environment?.slug}/${selected.name}`}</span>
                }
              />
            ) : null}
            <KV label={t("common.status")} value={<StatusTag status={selected.status} />} />
            <KV label={t("integrations.secretRef")} value={selected.secretRef ?? "-"} />
            <KV label={t("integrations.lastSync")} value={formatDateTime(selected.lastSyncAt, locale)} />
            <div>
              <p className="mb-2 text-[13px] font-medium">{t("integrations.capabilities")}</p>
              <div className="flex flex-wrap gap-1.5">
                {selected.capabilities.map((c) => (
                  <Tag key={c} tone="primary" dot={false}>
                    {c}
                  </Tag>
                ))}
              </div>
            </div>
            <div>
              <p className="mb-2 text-[13px] font-medium">{t("integrations.config")}</p>
              <JsonView value={selected.config} />
            </div>
            <div>
              <p className="mb-2 text-[13px] font-medium">Health</p>
              <JsonView value={selected.health} />
            </div>
            <div>
              <p className="mb-2 text-[13px] font-medium">{t("integrations.checkpoint")}</p>
              <JsonView value={selected.checkpoint} />
            </div>
            <div>
              <p className="mb-2 text-[13px] font-medium">{t("integrations.errors")}</p>
              <ul className="flex flex-col gap-1.5 text-xs">
                {selected.errors.map((e, i) => (
                  <li key={i} className="rounded-md bg-danger-soft px-3 py-2 text-danger">
                    <span className="block text-[11px] opacity-80">{formatDateTime(e.occurredAt, locale)}</span>
                    {e.message}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        ) : null}
      </Sheet>
      <Sheet
        open={!!editing}
        onOpenChange={(o) => !o && setEditing(null)}
        title={editing?.lockVersion ? t("common.edit") : t("integrations.add")}
        footer={
          <Button
            variant="primary"
            loading={saveState.loading}
            onClick={async () => {
              if (!editing) return;
              try {
                await save({
                  variables: {
                    environmentId,
                    input: {
                      name: editing.name,
                      kind: editing.kind,
                      config: editing.config,
                      secretRef: editing.secretRef || null,
                      enabled: editing.enabled,
                      lockVersion: editing.lockVersion,
                    },
                  },
                });
                toast.success(t("common.saved"));
                setEditing(null);
                refetch();
              } catch (e) {
                toast.error(e instanceof Error ? e.message : t("common.error"));
              }
            }}
          >
            {t("common.save")}
          </Button>
        }
      >
        {editing ? (
          <div className="flex flex-col gap-4">
            <Field label={t("common.name")} hint={t("validation.slug")}>
              {(id) => (
                <Input
                  id={id}
                  value={editing.name}
                  disabled={!!editing.lockVersion}
                  onChange={(e) => setEditing({ ...editing, name: e.target.value })}
                />
              )}
            </Field>
            <Field label={t("common.kind")}>
              {(id) => (
                <Select
                  id={id}
                  value={editing.kind}
                  disabled={!!editing.lockVersion}
                  onChange={(e) => setEditing({ ...editing, kind: e.target.value, config: {} })}
                >
                  {data?.integrationKinds.map((k) => (
                    <option key={k} value={k}>
                      {k}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
            <Field label={t("integrations.secretRef")} hint={t("integrations.secretHint")}>
              {(id) => (
                <Select
                  id={id}
                  value={editing.secretRef}
                  onChange={(e) => setEditing({ ...editing, secretRef: e.target.value })}
                >
                  <option value="">{t("common.none")}</option>
                  {data?.secretNames.map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
            {(FIELDS[editing.kind] ?? []).map((f) => (
              <Field key={f.key} label={t(f.label)}>
                {(id) => (
                  <Input
                    id={id}
                    type={f.type ?? "text"}
                    value={String(editing.config[f.key] ?? "")}
                    onChange={(e) =>
                      setEditing({
                        ...editing,
                        config: {
                          ...editing.config,
                          [f.key]: f.type === "number" ? Number(e.target.value) : e.target.value,
                        },
                      })
                    }
                  />
                )}
              </Field>
            ))}
            <Notice tone="info">{t("integrations.secretHint")}</Notice>
          </div>
        ) : null}
      </Sheet>
      <Sheet
        open={secretOpen}
        onOpenChange={setSecretOpen}
        title={t("integrations.secrets")}
        footer={
          <Button
            variant="primary"
            disabled={!secret.name || !secret.value}
            onClick={async () => {
              try {
                await putSecret({ variables: { environmentId, ...secret } });
                setSecret({ name: "", value: "" });
                toast.success(t("integrations.secretStored"));
                refetch();
              } catch (e) {
                toast.error(e instanceof Error ? e.message : t("common.error"));
              }
            }}
          >
            {t("integrations.putSecret")}
          </Button>
        }
      >
        <div className="flex flex-col gap-4">
          <ul className="flex flex-wrap gap-1.5">
            {data?.secretNames.map((s) => (
              <Tag key={s} tone="neutral" dot={false}>
                {s}
              </Tag>
            ))}
          </ul>
          <Field label={t("integrations.secretName")}>
            {(id) => (
              <Input id={id} value={secret.name} onChange={(e) => setSecret({ ...secret, name: e.target.value })} />
            )}
          </Field>
          <Field label={t("integrations.secretValue")}>
            {(id) => (
              <Input
                id={id}
                type="password"
                autoComplete="off"
                value={secret.value}
                onChange={(e) => setSecret({ ...secret, value: e.target.value })}
              />
            )}
          </Field>
        </div>
      </Sheet>
      <ConfirmDialog
        open={!!toDelete}
        onOpenChange={(o) => !o && setToDelete(null)}
        title={t("common.delete")}
        description={t("integrations.deleteConfirm")}
        danger
        onConfirm={async () => {
          if (toDelete) await remove({ variables: { id: toDelete } });
          setSelectedId(null);
          refetch();
        }}
      />
    </div>
  );
}
