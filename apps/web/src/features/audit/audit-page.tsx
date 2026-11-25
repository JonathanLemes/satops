import { useLazyQuery, useQuery } from "@apollo/client/react";
import { Info, Search } from "lucide-react";
import { useEffect, useState } from "react";
import { useSearchParams } from "react-router";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { useEnvironmentId, useSession } from "@/lib/session";
import { formatDateTime } from "@/lib/utils";
import { DataTable } from "@/components/data/data-table";
import { JsonView, Sats, Timeline } from "@/components/data/display";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { EmptyState, KV, Notice, PageHeader, Panel, PanelHeader, Segmented, StatusTag } from "@/components/ui/misc";
import { Sheet } from "@/components/ui/overlay";

const TIMELINE = graphql(`
  query OperationTimeline($environmentId: ID!, $operationId: String!) {
    operationTimeline(environmentId: $environmentId, operationId: $operationId) {
      operation {
        operationId
        kind
        state
        accountRef
        amountSats
        txid
        vout
        generation
      }
      journals {
        id
        entryKind
        ruleName
        ruleVersion
        description
        postedAt
        correlationId
        postings {
          id
          accountCode
          direction
          amountSats
        }
      }
      events {
        id
        seq
        eventType
        observedAt
        aggregateId
        correlationId
        payload
      }
    }
  }
`);

const AUDIT = graphql(`
  query AuditLog($environmentId: ID, $action: String) {
    auditLog(environmentId: $environmentId, action: $action, limit: 200) {
      id
      actorEmail
      action
      resourceType
      resourceId
      changes
      ip
      insertedAt
    }
  }
`);

const EVENT_TONES: Record<string, "success" | "warning" | "danger" | "primary" | "default"> = {
  "transaction.observed": "default",
  "transaction.confirmed": "success",
  "transaction.unconfirmed": "warning",
  "chain.reorganized": "danger",
  "ledger.deposit_credited": "success",
  "ledger.deposit_reversed": "danger",
  "reconciliation.completed": "primary",
  "reconciliation.discrepancy_detected": "danger",
};

export default function AuditPage() {
  const { t, locale } = useI18n();
  const environmentId = useEnvironmentId();
  const { can } = useSession();
  const [params, setParams] = useSearchParams();
  const [tab, setTab] = useState<"timeline" | "log">(
    params.get("operation") || !can("audit.read") ? "timeline" : "timeline",
  );
  const [operation, setOperation] = useState(params.get("operation") ?? "");
  const [load, timeline] = useLazyQuery(TIMELINE);
  const [actionFilter, setActionFilter] = useState("");
  const log = useQuery(AUDIT, {
    variables: { environmentId, action: actionFilter || null },
    skip: !can("audit.read") || tab !== "log",
  });
  const [selected, setSelected] = useState<{ action: string; changes: unknown } | null>(null);

  useEffect(() => {
    const op = params.get("operation");
    if (op) load({ variables: { environmentId, operationId: op } });
  }, [params, environmentId, load]);

  const tl = timeline.data?.operationTimeline;
  const items = [
    ...(tl?.events ?? []).map((e) => ({
      id: `e-${e.id}`,
      sort: e.observedAt,
      title: e.eventType,
      time: e.observedAt,
      tone: EVENT_TONES[e.eventType] ?? ("default" as const),
      description: e.payload?.reason
        ? String(e.payload.reason)
        : e.payload?.block_height
          ? `${t("transactions.block")} ${e.payload.block_height}`
          : null,
    })),
    ...(tl?.journals ?? []).map((j) => ({
      id: `j-${j.id}`,
      sort: j.postedAt,
      title: `${t("audit.journalPosted")}: ${j.entryKind}`,
      time: j.postedAt,
      tone: "primary" as const,
      description: (
        <span className="flex flex-col gap-1">
          <span>
            {t("audit.rule")} {j.ruleName} v{j.ruleVersion} · {j.description}
          </span>
          <span className="flex flex-col font-mono text-[11px]">
            {j.postings.map((p) => (
              <span key={p.id}>
                {p.direction === "debit" ? "Dr" : "Cr"} {p.accountCode} {p.amountSats}
              </span>
            ))}
          </span>
        </span>
      ),
    })),
  ].sort((a, b) => (a.sort < b.sort ? -1 : 1));

  return (
    <div className="flex flex-col gap-5">
      <PageHeader title={t("audit.title")} subtitle={t("audit.subtitle")} />
      {can("audit.read") ? (
        <Segmented
          label={t("audit.title")}
          value={tab}
          onChange={setTab}
          options={[
            { value: "timeline", label: t("audit.timeline") },
            { value: "log", label: t("audit.log") },
          ]}
        />
      ) : null}
      {tab === "timeline" ? (
        <Panel className="p-5">
          <form
            className="flex flex-wrap gap-3"
            onSubmit={(e) => {
              e.preventDefault();
              if (operation.trim()) setParams({ operation: operation.trim() });
            }}
          >
            <Input
              aria-label={t("audit.operation")}
              placeholder={t("audit.operationPlaceholder")}
              value={operation}
              onChange={(e) => setOperation(e.target.value)}
              className="min-w-[280px] flex-1 font-mono text-xs"
            />
            <Button type="submit" variant="primary">
              <Search /> {t("audit.lookup")}
            </Button>
          </form>
          {tl?.operation ? (
            <div className="mt-5 grid gap-2 rounded-md bg-surface-2 p-4 sm:grid-cols-2 lg:grid-cols-4">
              <KV label={t("common.kind")} value={tl.operation.kind} />
              <KV label={t("common.status")} value={<StatusTag status={tl.operation.state} />} />
              <KV label={t("wallets.accountRef")} value={tl.operation.accountRef} />
              <KV label={t("common.amount")} value={<Sats value={tl.operation.amountSats} />} />
            </div>
          ) : null}
          <div className="mt-6">
            {items.length ? <Timeline items={items} /> : <EmptyState icon={Search} title={t("audit.empty")} />}
          </div>
        </Panel>
      ) : (
        <Panel>
          <PanelHeader
            title={t("audit.log")}
            actions={
              <Input
                aria-label={t("audit.action")}
                placeholder={t("audit.action")}
                value={actionFilter}
                onChange={(e) => setActionFilter(e.target.value)}
                className="w-56"
              />
            }
          />
          <div className="px-5 pb-3">
            <Notice tone="info">
              <Info size={16} className="mt-0.5 shrink-0" />
              {t("audit.integrityNote")}
            </Notice>
          </div>
          <DataTable
            rows={log.data?.auditLog}
            loading={log.loading}
            rowKey={(r) => r.id}
            onRowClick={(r) => setSelected({ action: r.action, changes: r.changes })}
            columns={[
              { key: "time", header: t("common.time"), cell: (r) => formatDateTime(r.insertedAt, locale) },
              { key: "actor", header: t("audit.actor"), cell: (r) => r.actorEmail ?? "system" },
              {
                key: "action",
                header: t("audit.action"),
                primary: true,
                cell: (r) => <span className="font-mono text-xs">{r.action}</span>,
              },
              {
                key: "resource",
                header: t("audit.resource"),
                cell: (r) => `${r.resourceType ?? "-"} ${r.resourceId ? r.resourceId.slice(0, 12) : ""}`,
              },
              { key: "ip", header: "IP", cell: (r) => r.ip ?? "-" },
            ]}
            pageSize={30}
          />
        </Panel>
      )}
      <Sheet open={!!selected} onOpenChange={(o) => !o && setSelected(null)} title={selected?.action ?? ""}>
        <JsonView value={selected?.changes} maxHeight={700} />
      </Sheet>
    </div>
  );
}
