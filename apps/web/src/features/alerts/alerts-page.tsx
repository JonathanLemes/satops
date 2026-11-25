import { useMutation, useQuery } from "@apollo/client/react";
import { Plus } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { useEnvironmentId, useSession } from "@/lib/session";
import { relativeTime } from "@/lib/utils";
import { DataTable } from "@/components/data/data-table";
import { JsonView } from "@/components/data/display";
import { Button } from "@/components/ui/button";
import { Checkbox, Field, Input, Select } from "@/components/ui/input";
import { PageHeader, Panel, PanelHeader, Segmented, StatusTag, Tag } from "@/components/ui/misc";
import { Sheet } from "@/components/ui/overlay";

const ALERTS = graphql(`
  query Alerts($environmentId: ID!) {
    alerts(environmentId: $environmentId, limit: 100) {
      id
      title
      state
      severity
      count
      firstSeenAt
      lastSeenAt
      policyName
      details
      deliveries {
        id
        destination
        status
        attempts
        lastError
      }
    }
    alertPolicies(environmentId: $environmentId) {
      id
      name
      eventTypes
      severity
      cooldownSeconds
      destinations
      enabled
    }
  }
`);

const UPDATE = graphql(`
  mutation UpdateAlert($id: ID!, $action: String!) {
    updateAlert(id: $id, action: $action) {
      id
      state
    }
  }
`);

const RETRY = graphql(`
  mutation RetryAlertDelivery($id: ID!) {
    retryAlertDelivery(id: $id)
  }
`);

const SAVE_POLICY = graphql(`
  mutation SaveAlertPolicy($environmentId: ID!, $input: AlertPolicyInput!) {
    saveAlertPolicy(environmentId: $environmentId, input: $input) {
      id
    }
  }
`);

const EVENTS = [
  "node.disconnected",
  "integration.unavailable",
  "chain.reorganized",
  "reconciliation.discrepancy_detected",
  "reconciliation.completed",
  "reconciliation.incomplete",
  "experiment.finished",
  "ledger.invariant_violated",
  "ledger.deposit_reversed",
  "node.diverged",
];

export default function AlertsPage() {
  const { t, locale } = useI18n();
  const environmentId = useEnvironmentId();
  const { can } = useSession();
  const { data, loading, refetch } = useQuery(ALERTS, { variables: { environmentId } });
  const [update] = useMutation(UPDATE);
  const [retry] = useMutation(RETRY);
  const [savePolicy] = useMutation(SAVE_POLICY);
  const [tab, setTab] = useState<"occurrences" | "policies">("occurrences");
  const [selected, setSelected] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);
  const [policy, setPolicy] = useState({ name: "", eventTypes: [] as string[], severity: "warning", cooldownSeconds: 300, webhook: "" });
  const occurrence = data?.alerts.find((a) => a.id === selected);

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t("alerts.title")}
        subtitle={t("alerts.subtitle")}
        actions={
          can("alert.manage") ? (
            <Button variant="primary" onClick={() => setEditing(true)}>
              <Plus /> {t("alerts.newPolicy")}
            </Button>
          ) : null
        }
      />
      <Panel>
        <PanelHeader
          title={
            <Segmented
              label={t("alerts.title")}
              value={tab}
              onChange={setTab}
              options={[
                { value: "occurrences", label: t("alerts.occurrences") },
                { value: "policies", label: t("alerts.policies") },
              ]}
            />
          }
        />
        {tab === "occurrences" ? (
          <DataTable
            rows={data?.alerts}
            loading={loading}
            rowKey={(a) => a.id}
            onRowClick={(a) => setSelected(a.id)}
            empty={{ title: t("alerts.empty") }}
            columns={[
              { key: "title", header: t("common.name"), primary: true, cell: (a) => a.title },
              { key: "severity", header: t("alerts.severity"), cell: (a) => <Tag tone={a.severity === "critical" ? "danger" : a.severity === "warning" ? "warning" : "info"}>{a.severity}</Tag> },
              { key: "state", header: t("common.status"), cell: (a) => <StatusTag status={a.state} /> },
              { key: "count", header: t("alerts.count"), align: "right", cell: (a) => a.count, sortValue: (a) => a.count },
              { key: "last", header: t("alerts.lastSeen"), cell: (a) => relativeTime(a.lastSeenAt, locale), sortValue: (a) => a.lastSeenAt },
              { key: "policy", header: t("alerts.policies"), cell: (a) => a.policyName },
            ]}
            pageSize={25}
          />
        ) : (
          <DataTable
            rows={data?.alertPolicies}
            rowKey={(p) => p.id}
            columns={[
              { key: "name", header: t("common.name"), primary: true, cell: (p) => p.name },
              { key: "events", header: t("alerts.events"), cell: (p) => <span className="text-xs">{p.eventTypes.join(", ")}</span> },
              { key: "severity", header: t("alerts.severity"), cell: (p) => p.severity },
              { key: "cooldown", header: t("alerts.cooldown"), align: "right", cell: (p) => p.cooldownSeconds },
              { key: "enabled", header: t("common.status"), cell: (p) => <StatusTag status={p.enabled ? "applied" : "skipped"} /> },
            ]}
          />
        )}
      </Panel>
      <Sheet open={!!occurrence} onOpenChange={(o) => !o && setSelected(null)} title={occurrence?.title ?? ""} description={occurrence?.policyName ?? undefined}>
        {occurrence ? (
          <div className="flex flex-col gap-4">
            <div className="flex gap-2">
              {can("alert.manage") && occurrence.state === "firing" ? (
                <Button onClick={() => update({ variables: { id: occurrence.id, action: "acknowledge" } }).then(() => refetch())}>{t("alerts.acknowledge")}</Button>
              ) : null}
              {can("alert.manage") && occurrence.state !== "resolved" ? (
                <Button variant="primary" onClick={() => update({ variables: { id: occurrence.id, action: "resolve" } }).then(() => refetch())}>
                  {t("alerts.resolve")}
                </Button>
              ) : null}
            </div>
            <JsonView value={occurrence.details} />
            <h3 className="text-sm font-semibold">{t("alerts.deliveries")}</h3>
            <ul className="flex flex-col gap-2 text-xs">
              {occurrence.deliveries.map((d) => (
                <li key={d.id} className="flex items-center justify-between gap-2 rounded-md bg-surface-2 p-2">
                  <span>
                    {d.destination} · {d.attempts}x {d.lastError ? `· ${d.lastError}` : ""}
                  </span>
                  <span className="flex items-center gap-2">
                    <StatusTag status={d.status} />
                    {d.status.startsWith("failed") && can("alert.manage") ? (
                      <Button size="sm" onClick={() => retry({ variables: { id: d.id } }).then(() => refetch())}>
                        {t("alerts.retry")}
                      </Button>
                    ) : null}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        ) : null}
      </Sheet>
      <Sheet
        open={editing}
        onOpenChange={setEditing}
        title={t("alerts.newPolicy")}
        footer={
          <Button
            variant="primary"
            disabled={!policy.name || !policy.eventTypes.length}
            onClick={async () => {
              try {
                await savePolicy({
                  variables: {
                    environmentId,
                    input: {
                      name: policy.name,
                      eventTypes: policy.eventTypes,
                      severity: policy.severity,
                      cooldownSeconds: Number(policy.cooldownSeconds),
                      destinations: [{ type: "internal" }, ...(policy.webhook ? [{ type: "webhook", integration: policy.webhook }] : [])],
                    },
                  },
                });
                setEditing(false);
                refetch();
                toast.success(t("common.saved"));
              } catch (e) {
                toast.error(e instanceof Error ? e.message : t("common.error"));
              }
            }}
          >
            {t("common.save")}
          </Button>
        }
      >
        <div className="flex flex-col gap-4">
          <Field label={t("common.name")}>{(id) => <Input id={id} value={policy.name} onChange={(e) => setPolicy({ ...policy, name: e.target.value })} />}</Field>
          <fieldset className="flex flex-col gap-2">
            <legend className="mb-1 text-[13px] font-medium">{t("alerts.events")}</legend>
            {EVENTS.map((ev) => (
              <Checkbox
                key={ev}
                checked={policy.eventTypes.includes(ev)}
                onChange={(on) => setPolicy({ ...policy, eventTypes: on ? [...policy.eventTypes, ev] : policy.eventTypes.filter((x) => x !== ev) })}
                label={<span className="font-mono text-xs">{ev}</span>}
              />
            ))}
          </fieldset>
          <Field label={t("alerts.severity")}>
            {(id) => (
              <Select id={id} value={policy.severity} onChange={(e) => setPolicy({ ...policy, severity: e.target.value })}>
                <option value="info">info</option>
                <option value="warning">warning</option>
                <option value="critical">critical</option>
              </Select>
            )}
          </Field>
          <Field label={t("alerts.cooldown")}>{(id) => <Input id={id} type="number" min={0} value={policy.cooldownSeconds} onChange={(e) => setPolicy({ ...policy, cooldownSeconds: Number(e.target.value) })} />}</Field>
          <Field label={t("alerts.webhookIntegration")} hint={t("common.optional")}>{(id) => <Input id={id} value={policy.webhook} onChange={(e) => setPolicy({ ...policy, webhook: e.target.value })} />}</Field>
        </div>
      </Sheet>
    </div>
  );
}
