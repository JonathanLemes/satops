import "react-grid-layout/css/styles.css";
import "react-resizable/css/styles.css";
import { useMutation, useQuery } from "@apollo/client/react";
import { Download, LayoutGrid, Plus, RotateCcw, Settings2, Upload, X } from "lucide-react";
import { useMemo, useRef, useState } from "react";
import GridLayout, { WidthProvider, type Layout } from "react-grid-layout";
import { toast } from "sonner";
import { parse as parseYaml, stringify as stringifyYaml } from "yaml";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { useSession } from "@/lib/session";
import { downloadText } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Field, Input, Select } from "@/components/ui/input";
import { ErrorState, LoadingState, PageHeader } from "@/components/ui/misc";
import { Dialog, Menu, MenuContent, MenuItem, MenuTrigger } from "@/components/ui/overlay";
import { WIDGETS } from "./widgets/widgets";

const Grid = WidthProvider(GridLayout);

const DASHBOARDS = graphql(`
  query Dashboards($workspace: String!) {
    dashboards(workspace: $workspace) {
      id
      name
      title
      workspace
      spec
      isDefault
      shared
      lockVersion
    }
    widgetTypes {
      type
      minWidth
      minHeight
      permission
      workspaces
      refresh
    }
  }
`);

const SAVE = graphql(`
  mutation SaveDashboard($name: String!, $spec: JSON!, $lockVersion: Int) {
    saveDashboard(name: $name, spec: $spec, lockVersion: $lockVersion) {
      id
      lockVersion
    }
  }
`);

const RESTORE = graphql(`
  mutation RestoreDashboard($workspace: String!) {
    restoreDefaultDashboard(workspace: $workspace) {
      id
    }
  }
`);

interface WidgetSpec {
  id: string;
  type: string;
  title?: string;
  refreshInterval?: string;
  position: { x: number; y: number; width: number; height: number };
  config?: Record<string, unknown>;
}

interface DashboardSpec {
  title?: string;
  workspace: string;
  layout?: { columns: number };
  widgets: WidgetSpec[];
}

function parseRefresh(value?: string): number | undefined {
  const m = value?.match(/^(\d+)(ms|s|m)$/);
  if (!m) return undefined;
  const n = Number(m[1]);
  return m[2] === "ms" ? n : m[2] === "s" ? n * 1000 : n * 60_000;
}

export default function DashboardPage({ workspace }: { workspace: "customer" | "engineering" }) {
  const { t, tx } = useI18n();
  const { can } = useSession();
  const { data, loading, error, refetch } = useQuery(DASHBOARDS, { variables: { workspace } });
  const [save, saveState] = useMutation(SAVE);
  const [restore] = useMutation(RESTORE);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState<DashboardSpec | null>(null);
  const [settings, setSettings] = useState<WidgetSpec | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const dashboard = useMemo(() => {
    const list = data?.dashboards ?? [];
    return list.find((d) => !d.shared) ?? list.find((d) => d.isDefault) ?? list[0];
  }, [data]);

  const spec: DashboardSpec | null = draft ?? (dashboard?.spec as DashboardSpec | undefined) ?? null;
  const types = (data?.widgetTypes ?? []).filter((w) => w.workspaces.includes(workspace) && can(w.permission));
  const typeMeta = new Map(types.map((w) => [w.type, w]));
  const canEdit = can("dashboard.manage");

  const persist = async (next: DashboardSpec) => {
    if (!dashboard) return;
    try {
      await save({
        variables: { name: dashboard.name, spec: next, lockVersion: dashboard.shared ? null : dashboard.lockVersion },
      });
      await refetch();
      setDraft(null);
      toast.success(t("overview.saved"));
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("common.error"));
      throw e;
    }
  };

  if (loading && !data) return <LoadingState rows={8} />;
  if (error && !data) return <ErrorState onRetry={() => refetch()} />;

  const widgets = (spec?.widgets ?? []).filter((w) => typeMeta.has(w.type) || !editing);
  const layout: Layout[] = widgets.map((w) => ({
    i: w.id,
    x: w.position.x,
    y: w.position.y,
    w: w.position.width,
    h: w.position.height,
    minW: typeMeta.get(w.type)?.minWidth ?? 1,
    minH: typeMeta.get(w.type)?.minHeight ?? 1,
  }));

  const update = (fn: (s: DashboardSpec) => DashboardSpec) => spec && setDraft(fn(structuredClone(spec)));

  const onLayout = (next: Layout[]) => {
    if (!editing) return;
    update((s) => ({
      ...s,
      widgets: s.widgets.map((w) => {
        const l = next.find((n) => n.i === w.id);
        return l ? { ...w, position: { x: l.x, y: l.y, width: l.w, height: l.h } } : w;
      }),
    }));
  };

  const addWidget = (type: string) => {
    const meta = typeMeta.get(type);
    const id = `${type.replace(/[^a-z]/g, "-")}-${Math.random().toString(36).slice(2, 6)}`;
    const maxY = Math.max(0, ...widgets.map((w) => w.position.y + w.position.height));
    update((s) => ({
      ...s,
      widgets: [
        ...s.widgets,
        {
          id,
          type,
          position: {
            x: 0,
            y: maxY,
            width: Math.max(meta?.minWidth ?? 3, 3),
            height: Math.max(meta?.minHeight ?? 2, 2),
          },
        },
      ],
    }));
  };

  const exportYaml = () => {
    if (!spec || !dashboard) return;
    const doc = { apiVersion: "satops.io/v1alpha1", kind: "Dashboard", metadata: { name: dashboard.name }, spec };
    downloadText(`dashboard-${dashboard.name}.yaml`, stringifyYaml(doc));
  };

  const importYaml = async (file: File) => {
    try {
      const doc = parseYaml(await file.text(), { uniqueKeys: true }) as { kind?: string; spec?: DashboardSpec };
      if (doc?.kind !== "Dashboard" || !doc.spec || doc.spec.workspace !== workspace) throw new Error("invalid");
      await persist(doc.spec);
    } catch {
      toast.error(t("overview.importInvalid"));
    }
  };

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={workspace === "customer" ? t("overview.title") : t("overview.engineeringTitle")}
        subtitle={workspace === "customer" ? t("overview.subtitle") : t("overview.engineeringSubtitle")}
        actions={
          canEdit ? (
            editing ? (
              <>
                <Menu>
                  <MenuTrigger asChild>
                    <Button>
                      <Plus /> {t("overview.addWidget")}
                    </Button>
                  </MenuTrigger>
                  <MenuContent>
                    {types.map((w) => (
                      <MenuItem key={w.type} onSelect={() => addWidget(w.type)}>
                        {tx(`widgets.${w.type}`)}
                      </MenuItem>
                    ))}
                  </MenuContent>
                </Menu>
                <Button
                  variant="ghost"
                  onClick={async () => {
                    await restore({ variables: { workspace } });
                    setDraft(null);
                    await refetch();
                  }}
                >
                  <RotateCcw /> {t("overview.restore")}
                </Button>
                <Button variant="ghost" onClick={exportYaml}>
                  <Download /> {t("overview.exportYaml")}
                </Button>
                <Button variant="ghost" onClick={() => fileRef.current?.click()}>
                  <Upload /> {t("overview.importYaml")}
                </Button>
                <input
                  ref={fileRef}
                  type="file"
                  accept=".yaml,.yml"
                  className="hidden"
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    if (f) importYaml(f);
                    e.target.value = "";
                  }}
                />
                <Button
                  variant="primary"
                  loading={saveState.loading}
                  onClick={async () => {
                    try {
                      if (draft) await persist(draft);
                      setEditing(false);
                    } catch {
                      return;
                    }
                  }}
                >
                  {t("overview.done")}
                </Button>
              </>
            ) : (
              <Button onClick={() => setEditing(true)}>
                <LayoutGrid /> {t("overview.edit")}
              </Button>
            )
          ) : null
        }
      />
      <Grid
        className="-mx-[10px]"
        layout={layout}
        cols={12}
        rowHeight={96}
        margin={[12, 12]}
        isDraggable={editing}
        isResizable={editing}
        draggableCancel=".no-drag"
        onLayoutChange={onLayout}
        compactType="vertical"
      >
        {widgets.map((w) => {
          const Component = WIDGETS[w.type];
          const title = w.title ?? tx(`widgets.${w.type}`);
          return (
            <div key={w.id} className={editing ? "relative rounded-lg ring-2 ring-primary/30" : "relative"}>
              {Component ? <Component title={title} refreshMs={parseRefresh(w.refreshInterval)} /> : null}
              {editing ? (
                <div className="no-drag absolute right-2 top-2 z-10 flex gap-1">
                  <Button
                    size="icon-sm"
                    variant="secondary"
                    aria-label={t("overview.widgetSettings")}
                    onClick={() => setSettings(w)}
                  >
                    <Settings2 />
                  </Button>
                  <Button
                    size="icon-sm"
                    variant="secondary"
                    aria-label={t("overview.removeWidget")}
                    onClick={() => update((s) => ({ ...s, widgets: s.widgets.filter((x) => x.id !== w.id) }))}
                  >
                    <X />
                  </Button>
                </div>
              ) : null}
            </div>
          );
        })}
      </Grid>
      <Dialog open={!!settings} onOpenChange={(o) => !o && setSettings(null)} title={t("overview.widgetSettings")}>
        {settings ? (
          <form
            className="flex flex-col gap-4"
            onSubmit={(e) => {
              e.preventDefault();
              update((s) => ({ ...s, widgets: s.widgets.map((w) => (w.id === settings.id ? settings : w)) }));
              setSettings(null);
            }}
          >
            <Field label={t("overview.title_")}>
              {(id) => (
                <Input
                  id={id}
                  value={settings.title ?? ""}
                  onChange={(e) => setSettings({ ...settings, title: e.target.value || undefined })}
                />
              )}
            </Field>
            <Field label={t("overview.refreshInterval")}>
              {(id) => (
                <Select
                  id={id}
                  value={settings.refreshInterval ?? ""}
                  onChange={(e) => setSettings({ ...settings, refreshInterval: e.target.value || undefined })}
                >
                  <option value="">Realtime</option>
                  <option value="15s">15s</option>
                  <option value="30s">30s</option>
                  <option value="1m">1m</option>
                  <option value="5m">5m</option>
                </Select>
              )}
            </Field>
            <div className="flex justify-end gap-2">
              <Button variant="ghost" onClick={() => setSettings(null)}>
                {t("common.cancel")}
              </Button>
              <Button type="submit" variant="primary">
                {t("common.save")}
              </Button>
            </div>
          </form>
        ) : null}
      </Dialog>
    </div>
  );
}
