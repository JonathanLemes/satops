import { useMutation, useQuery } from "@apollo/client/react";
import { ArrowLeft, CheckCircle2, Download, FileUp, History, Play, ShieldCheck, TriangleAlert } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { Link, useNavigate, useParams, useSearchParams } from "react-router";
import { toast } from "sonner";
import { parseDocument, stringify } from "yaml";
import { graphql } from "@/gql";
import type { PlanConfigMutation } from "@/gql/graphql";
import { useI18n } from "@/i18n";
import { useSession } from "@/lib/session";
import { downloadText, formatDateTime } from "@/lib/utils";
import { YamlDiff, YamlEditor, type EditorMarker } from "@/components/data/yaml-editor";
import { Button } from "@/components/ui/button";
import { Field, Input, Select } from "@/components/ui/input";
import { ErrorState, LoadingState, Notice, PageHeader, Panel, PanelHeader, Segmented, StatusTag, Tag } from "@/components/ui/misc";
import { ConfirmDialog, Sheet } from "@/components/ui/overlay";
import { KINDS, knownPaths, schemaFor, template, validateLocal, type Issue } from "./schema";
import { SchemaForm } from "./schema-form";

const RESOURCE = graphql(`
  query ConfigResource($kind: String!, $name: String!) {
    configResource(kind: $kind, name: $name) {
      id
      kind
      name
      desiredRevision
      appliedRevision
      status
      statusMessage
      observed
      document
      updatedAt
      revisions {
        revision
        yaml
        spec
        authorEmail
        message
        insertedAt
      }
    }
  }
`);

const VALIDATE = graphql(`
  mutation ValidateConfig($yaml: String) {
    validateConfig(yaml: $yaml) {
      valid
      document
      canonicalYaml
      errors {
        path
        message
        line
        column
      }
    }
  }
`);

const PLAN = graphql(`
  mutation PlanConfig($document: JSON!) {
    planConfig(document: $document) {
      action
      kind
      name
      currentRevision
      impact
      canonicalYaml
      currentYaml
      changes {
        op
        path
        old
        new
      }
    }
  }
`);

const APPLY = graphql(`
  mutation ApplyConfig($document: JSON!, $expectedRevision: Int, $message: String) {
    applyConfig(document: $document, expectedRevision: $expectedRevision, message: $message) {
      changed
      resource {
        kind
        name
        desiredRevision
        appliedRevision
        status
        statusMessage
      }
    }
  }
`);

const REAPPLY = graphql(`
  mutation ReapplyConfig($kind: String!, $name: String!, $revision: Int!) {
    reapplyConfig(kind: $kind, name: $name, revision: $revision) {
      changed
    }
  }
`);

type Doc = Record<string, unknown> & { kind?: string; metadata?: { name?: string }; spec?: Record<string, unknown> };
type Plan = NonNullable<PlanConfigMutation["planConfig"]>;

function toYaml(doc: Doc) {
  return stringify(doc, { lineWidth: 0 });
}

export default function ConfigEditorPage() {
  const params = useParams();
  const [search] = useSearchParams();
  const navigate = useNavigate();
  const { t } = useI18n();
  const { can, environment } = useSession();
  const isNew = !params.kind;
  const [kind, setKind] = useState<string>(params.kind ?? search.get("kind") ?? "Environment");
  const resource = useQuery(RESOURCE, { variables: { kind: params.kind ?? "", name: params.name ?? "" }, skip: isNew });
  const [validate, validation] = useMutation(VALIDATE);
  const [planMutation, planState] = useMutation(PLAN);
  const [apply, applyState] = useMutation(APPLY);
  const [reapply] = useMutation(REAPPLY);
  const [mode, setMode] = useState<"form" | "yaml">("form");
  const [doc, setDoc] = useState<Doc | null>(null);
  const [yamlText, setYamlText] = useState("");
  const [parseIssue, setParseIssue] = useState<EditorMarker | null>(null);
  const [serverIssues, setServerIssues] = useState<Issue[] | null>(null);
  const [plan, setPlan] = useState<Plan | null>(null);
  const [message, setMessage] = useState("");
  const [conflict, setConflict] = useState<number | null>(null);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [reapplyRev, setReapplyRev] = useState<number | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const res = resource.data?.configResource;
  const canApply = can("config.apply");

  useEffect(() => {
    if (isNew) {
      const d = template(kind, environment?.slug ?? "default-sandbox") as Doc;
      setDoc(d);
      setYamlText(toYaml(d));
    }
  }, [isNew, kind, environment?.slug]);

  useEffect(() => {
    if (res?.document && !doc) {
      setDoc(res.document as Doc);
      setYamlText(toYaml(res.document as Doc));
    }
  }, [res, doc]);

  const schema = schemaFor(doc?.kind ?? kind);
  const localIssues = useMemo(() => (doc ? validateLocal(doc) : []), [doc]);
  const unknown = useMemo(() => (doc && schema ? knownPaths(schema, doc) : []), [doc, schema]);
  const errorMap = useMemo(() => Object.fromEntries(localIssues.map((i) => [i.path, i.message])), [localIssues]);

  const onYamlChange = (text: string) => {
    setYamlText(text);
    setPlan(null);
    const parsed = parseDocument(text, { uniqueKeys: true });
    if (parsed.errors.length) {
      const e = parsed.errors[0]!;
      setParseIssue({ line: e.linePos?.[0]?.line ?? 1, column: e.linePos?.[0]?.col, message: e.message.split("\n")[0] ?? e.message });
      return;
    }
    setParseIssue(null);
    const value = parsed.toJS({ maxAliasCount: 0 }) as Doc;
    if (value && typeof value === "object") setDoc(value);
  };

  const onFormChange = (next: Doc) => {
    setDoc(next);
    setYamlText(toYaml(next));
    setPlan(null);
  };

  const switchMode = (next: "form" | "yaml") => {
    if (next === "form" && parseIssue) {
      toast.error(t("config.parseError"));
      return;
    }
    if (next === "yaml" && doc) setYamlText(toYaml(doc));
    setMode(next);
  };

  const runValidate = async () => {
    const r = await validate({ variables: { yaml: yamlText } });
    const v = r.data?.validateConfig;
    setServerIssues(v?.valid ? [] : (v?.errors ?? []).map((e) => ({ path: e.path ?? (e.line ? t("config.line", { line: e.line }) : "/"), message: e.message })));
    return v;
  };

  const runPlan = async () => {
    const v = await runValidate();
    if (!v?.valid) return;
    try {
      const r = await planMutation({ variables: { document: v.document } });
      setPlan(r.data?.planConfig ?? null);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("common.error"));
    }
  };

  const runApply = async () => {
    if (!plan || !doc) return;
    try {
      const r = await apply({ variables: { document: doc, expectedRevision: plan.currentRevision ?? 0, message: message || null } });
      const result = r.data?.applyConfig;
      if (!result) return;
      toast.success(result.changed ? t("config.applied_") : t("config.unchanged"));
      setPlan(null);
      if (isNew) navigate(`/engineering/configuration/${result.resource.kind}/${result.resource.name}`, { replace: true });
      else resource.refetch();
    } catch (e) {
      const ext = (e as { graphQLErrors?: { extensions?: { code?: string; currentRevision?: number } }[]; errors?: { extensions?: { code?: string; currentRevision?: number } }[] }) ?? {};
      const first = (ext.errors ?? ext.graphQLErrors ?? [])[0];
      if (first?.extensions?.code === "CONFLICT") setConflict(first.extensions.currentRevision ?? 0);
      else toast.error(e instanceof Error ? e.message : t("common.error"));
    }
  };

  const importFile = async (file: File) => {
    const text = await file.text();
    onYamlChange(text);
    setMode("yaml");
  };

  if (!isNew && resource.loading && !resource.data) return <LoadingState rows={10} />;
  if (!isNew && (resource.error || (!resource.loading && !res))) return <ErrorState onRetry={() => resource.refetch()} />;

  const markers: EditorMarker[] = [
    ...(parseIssue ? [parseIssue] : []),
    ...(validation.data?.validateConfig.errors ?? []).filter((e) => e.line).map((e) => ({ line: e.line!, column: e.column ?? undefined, message: e.message })),
  ];

  return (
    <div className="flex flex-col gap-5">
      <Link to="/engineering/configuration" className="inline-flex items-center gap-2 text-sm text-text-secondary hover:text-text">
        <ArrowLeft size={16} /> {t("config.resources")}
      </Link>
      <PageHeader
        title={isNew ? t("config.new") : `${res?.kind} / ${res?.name}`}
        subtitle={!isNew && res ? `${t("config.desired")} ${res.desiredRevision} · ${t("config.applied")} ${res.appliedRevision ?? "-"}` : undefined}
        actions={
          <>
            {!isNew && res ? <StatusTag status={res.status} /> : null}
            <Button onClick={() => fileRef.current?.click()}>
              <FileUp /> {t("config.import")}
            </Button>
            <input
              ref={fileRef}
              type="file"
              accept=".yaml,.yml"
              className="hidden"
              onChange={(e) => {
                const f = e.target.files?.[0];
                e.target.value = "";
                if (f) importFile(f);
              }}
            />
            <Button onClick={() => doc && downloadText(`${doc.kind}-${doc.metadata?.name || "resource"}.yaml`, toYaml(doc))}>
              <Download /> {t("config.export")}
            </Button>
            {!isNew ? (
              <Button onClick={() => setHistoryOpen(true)}>
                <History /> {t("config.history")}
              </Button>
            ) : null}
          </>
        }
      />
      {res?.statusMessage ? <Notice tone="danger">{res.statusMessage}</Notice> : null}
      <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_380px]">
        <Panel>
          <PanelHeader
            title={
              <Segmented
                label={t("config.title")}
                value={mode}
                onChange={switchMode}
                options={[
                  { value: "form", label: t("config.form") },
                  { value: "yaml", label: t("config.yaml") },
                ]}
              />
            }
            actions={
              isNew ? (
                <Select
                  aria-label={t("config.kindLabel")}
                  value={kind}
                  onChange={(e) => {
                    setKind(e.target.value);
                    setDoc(null);
                    setPlan(null);
                  }}
                  className="w-56"
                >
                  {KINDS.map((k) => (
                    <option key={k} value={k}>
                      {k}
                    </option>
                  ))}
                </Select>
              ) : null
            }
          />
          <div className="flex flex-col gap-4 px-5 pb-5">
            {unknown.length ? <Notice tone="warning">{t("config.unknownFields")}</Notice> : null}
            {mode === "yaml" ? (
              <>
                <YamlEditor value={yamlText} onChange={onYamlChange} markers={markers} readOnly={!canApply} ariaLabel="YAML" />
                <p className="text-xs text-text-muted">{t("config.normalizationNote")}</p>
              </>
            ) : doc && schema?.properties ? (
              <div className="flex flex-col gap-5">
                <Field label="metadata.name" hint={t("validation.slug")} error={errorMap["/metadata/name"]}>
                  {(id) => (
                    <Input
                      id={id}
                      value={doc.metadata?.name ?? ""}
                      disabled={!isNew}
                      onChange={(e) => onFormChange({ ...doc, metadata: { ...(doc.metadata ?? {}), name: e.target.value } })}
                    />
                  )}
                </Field>
                <SchemaForm
                  schema={schema.properties.spec!}
                  value={doc.spec as Record<string, never>}
                  onChange={(spec) => onFormChange({ ...doc, spec })}
                  path="/spec"
                  errors={errorMap}
                />
              </div>
            ) : (
              <LoadingState />
            )}
          </div>
        </Panel>
        <div className="flex flex-col gap-5">
          <Panel className="gap-3 p-5">
            <div className="flex items-center gap-2">
              {localIssues.length || parseIssue ? <TriangleAlert size={16} className="text-warning" /> : <ShieldCheck size={16} className="text-success" />}
              <span className="text-[13px] font-semibold">{localIssues.length || parseIssue ? t("config.invalid") : t("config.valid")}</span>
            </div>
            {parseIssue ? (
              <p className="text-xs text-danger">
                {t("config.line", { line: parseIssue.line })}: {parseIssue.message}
              </p>
            ) : null}
            <ul className="flex flex-col gap-1 text-xs">
              {[...localIssues, ...(serverIssues ?? [])].slice(0, 12).map((i, n) => (
                <li key={n} className="text-danger">
                  <code>{i.path}</code> {i.message}
                </li>
              ))}
            </ul>
            {serverIssues && serverIssues.length === 0 ? (
              <p className="flex items-center gap-1.5 text-xs text-success">
                <CheckCircle2 size={14} /> Backend: {t("config.valid")}
              </p>
            ) : null}
            <div className="flex flex-wrap gap-2">
              <Button onClick={runValidate} loading={validation.loading}>
                {t("config.validate")}
              </Button>
              <Button variant="primary" onClick={runPlan} loading={planState.loading} disabled={!!parseIssue}>
                {t("config.plan")}
              </Button>
            </div>
          </Panel>
          {!isNew && res ? (
            <Panel className="gap-2 p-5">
              <h3 className="text-[13px] font-semibold">{t("config.observed")}</h3>
              <pre className="max-h-60 overflow-auto rounded-md bg-surface-2 p-3 font-mono text-[11px]">{JSON.stringify(res.observed, null, 2)}</pre>
              <p className="text-[11px] text-text-muted">{formatDateTime(res.updatedAt, "en")}</p>
            </Panel>
          ) : null}
        </div>
      </div>
      {plan ? (
        <Panel>
          <PanelHeader
            title={`${t("config.plan")}: ${plan.action}`}
            subtitle={`${plan.kind}/${plan.name}`}
            actions={
              canApply ? (
                <div className="flex flex-wrap items-center gap-2">
                  <Input aria-label={t("config.message")} placeholder={t("config.message")} value={message} onChange={(e) => setMessage(e.target.value)} className="w-64" />
                  <Button variant="primary" onClick={runApply} loading={applyState.loading} disabled={plan.action === "noop"}>
                    <Play /> {t("config.apply")}
                  </Button>
                </div>
              ) : null
            }
          />
          <div className="flex flex-col gap-4 px-5 pb-5">
            <div>
              <h3 className="mb-2 text-[13px] font-semibold">{t("config.impact")}</h3>
              <ul className="list-disc pl-5 text-[13px] text-text-secondary">
                {plan.impact.map((i) => (
                  <li key={i}>{i}</li>
                ))}
              </ul>
            </div>
            <div>
              <h3 className="mb-2 text-[13px] font-semibold">{t("config.changes")}</h3>
              {plan.changes.length === 0 ? <p className="text-xs text-text-muted">{t("config.noChanges")}</p> : null}
              <ul className="flex flex-col gap-1 font-mono text-[11.5px]">
                {plan.changes.map((c) => (
                  <li key={c.path} className="flex flex-wrap gap-2">
                    <Tag tone={c.op === "add" ? "success" : c.op === "remove" ? "danger" : "warning"} dot={false}>
                      {c.op === "add" ? t("config.added") : c.op === "remove" ? t("config.removed") : t("config.replaced")}
                    </Tag>
                    <span>{c.path}</span>
                    {c.op === "replace" ? (
                      <span className="text-text-muted">
                        {JSON.stringify(c.old)} → {JSON.stringify(c.new)}
                      </span>
                    ) : null}
                  </li>
                ))}
              </ul>
            </div>
            <YamlDiff original={plan.currentYaml ?? ""} modified={plan.canonicalYaml} />
          </div>
        </Panel>
      ) : null}
      <Sheet open={historyOpen} onOpenChange={setHistoryOpen} title={t("config.history")} description={t("config.reapplyNote")} width={720}>
        <ul className="flex flex-col gap-4">
          {res?.revisions.map((r) => (
            <li key={r.revision} className="flex flex-col gap-2 rounded-md border border-border p-3">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span className="text-[13px] font-semibold">
                  {t("config.revision")} {r.revision}
                  {r.revision === res.appliedRevision ? <Tag tone="success" className="ml-2">{t("status.applied")}</Tag> : null}
                </span>
                <span className="text-xs text-text-muted">
                  {r.authorEmail ?? "system"} · {formatDateTime(r.insertedAt, "en")}
                </span>
              </div>
              {r.message ? <p className="text-xs text-text-secondary">{r.message}</p> : null}
              <pre className="max-h-48 overflow-auto rounded bg-surface-2 p-2 font-mono text-[11px]">{r.yaml}</pre>
              {canApply && r.revision !== res.desiredRevision ? (
                <Button size="sm" className="self-start" onClick={() => setReapplyRev(r.revision)}>
                  {t("config.reapply")}
                </Button>
              ) : null}
            </li>
          ))}
        </ul>
      </Sheet>
      <ConfirmDialog
        open={reapplyRev !== null}
        onOpenChange={(o) => !o && setReapplyRev(null)}
        title={t("config.reapply")}
        description={t("config.reapplyNote")}
        onConfirm={async () => {
          if (!res || reapplyRev === null) return;
          try {
            await reapply({ variables: { kind: res.kind, name: res.name, revision: reapplyRev } });
            setDoc(null);
            setHistoryOpen(false);
            await resource.refetch();
            toast.success(t("config.applied_"));
          } catch (e) {
            toast.error(e instanceof Error ? e.message : t("common.error"));
          }
        }}
      />
      <ConfirmDialog
        open={conflict !== null}
        onOpenChange={(o) => !o && setConflict(null)}
        title={t("common.error")}
        description={t("config.conflict", { revision: conflict ?? 0 })}
        confirmLabel={t("common.refresh")}
        onConfirm={async () => {
          setDoc(null);
          setPlan(null);
          await resource.refetch();
        }}
      />
    </div>
  );
}
