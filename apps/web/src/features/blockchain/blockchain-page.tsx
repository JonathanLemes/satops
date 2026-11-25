import { useQuery } from "@apollo/client/react";
import { Info } from "lucide-react";
import { useState } from "react";
import { graphql } from "@/gql";
import type { DomainEventsQuery } from "@/gql/graphql";
import { useI18n } from "@/i18n";
import { useEnvironmentId } from "@/lib/session";
import { formatDateTime, formatNumber, relativeTime } from "@/lib/utils";
import { DataTable } from "@/components/data/data-table";
import { EventInspector, Hash, MetricCard } from "@/components/data/display";
import { Input } from "@/components/ui/input";
import { ErrorState, LoadingState, Notice, PageHeader, Panel, PanelHeader, Segmented, Tag } from "@/components/ui/misc";
import { Sheet } from "@/components/ui/overlay";

const CHAIN = graphql(`
  query ChainOverview($environmentId: ID!) {
    chainOverview(environmentId: $environmentId) {
      checkpointHeight
      checkpointHash
      checkpointUpdatedAt
      mempoolSize
      transactionCounts
      diverged
      referenceNode
      requiredConfirmations
      tip {
        height
        hash
        blockTime
      }
      reorganizations {
        id
        seq
        observedAt
        payload
        eventType
        schemaVersion
        aggregateType
        aggregateId
        correlationId
        causationId
      }
      staleBlocks {
        hash
        height
        disconnectedAt
      }
    }
  }
`);

const BLOCKS = graphql(`
  query Blocks($environmentId: ID!) {
    blocks(environmentId: $environmentId, limit: 30) {
      hash
      height
      txCount
      blockTime
      connectedAt
      inBestChain
    }
  }
`);

const EVENTS = graphql(`
  query DomainEvents($environmentId: ID!, $types: [String!]) {
    events(environmentId: $environmentId, types: $types, limit: 100) {
      id
      seq
      eventType
      schemaVersion
      aggregateType
      aggregateId
      correlationId
      causationId
      observedAt
      payload
    }
  }
`);

type EventRow = DomainEventsQuery["events"][number];

export default function BlockchainPage() {
  const { t, locale } = useI18n();
  const environmentId = useEnvironmentId();
  const chain = useQuery(CHAIN, { variables: { environmentId } });
  const [tab, setTab] = useState<"blocks" | "reorgs" | "events">("blocks");
  const blocks = useQuery(BLOCKS, { variables: { environmentId }, skip: tab !== "blocks" });
  const [typeFilter, setTypeFilter] = useState("");
  const events = useQuery(EVENTS, { variables: { environmentId, types: typeFilter ? [typeFilter] : null }, skip: tab !== "events" });
  const [inspect, setInspect] = useState<EventRow | null>(null);
  const c = chain.data?.chainOverview;

  if (chain.loading && !chain.data) return <LoadingState rows={8} />;
  if (chain.error && !chain.data) return <ErrorState onRetry={() => chain.refetch()} />;

  return (
    <div className="flex flex-col gap-5">
      <PageHeader title={t("blockchain.title")} subtitle={t("blockchain.subtitle")} />
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <MetricCard label={t("blockchain.tip")} value={formatNumber(c?.tip?.height, locale)} hint={<Hash value={c?.tip?.hash} copy={false} />} glow="blue" />
        <MetricCard label={t("blockchain.checkpoint")} value={formatNumber(c?.checkpointHeight, locale)} hint={relativeTime(c?.checkpointUpdatedAt, locale)} glow="violet" />
        <MetricCard label={t("nodes.mempool")} value={formatNumber(c?.mempoolSize, locale)} glow="amber" />
        <MetricCard label={t("blockchain.reorgs")} value={c?.reorganizations.length ?? 0} hint={`${t("nodes.reference")}: ${c?.referenceNode ?? "-"}`} glow={c?.reorganizations.length ? "red" : "green"} />
      </div>
      <Notice tone="info">
        <Info size={16} className="mt-0.5 shrink-0" />
        {t("blockchain.mempoolNote")}
      </Notice>
      <Panel>
        <PanelHeader
          title={
            <Segmented
              label={t("blockchain.title")}
              value={tab}
              onChange={setTab}
              options={[
                { value: "blocks", label: t("blockchain.blocks") },
                { value: "reorgs", label: t("blockchain.reorgs") },
                { value: "events", label: t("blockchain.events") },
              ]}
            />
          }
          actions={
            tab === "events" ? (
              <Input aria-label={t("blockchain.eventType")} placeholder={t("blockchain.eventType")} value={typeFilter} onChange={(e) => setTypeFilter(e.target.value.trim())} className="w-60 font-mono text-xs" />
            ) : null
          }
        />
        {tab === "blocks" ? (
          <DataTable
            rows={blocks.data?.blocks}
            loading={blocks.loading}
            rowKey={(b) => b.hash}
            columns={[
              { key: "height", header: t("nodes.height"), primary: true, cell: (b) => formatNumber(b.height, locale) },
              { key: "hash", header: "Hash", cell: (b) => <Hash value={b.hash} size={12} /> },
              { key: "tx", header: t("blockchain.txCount"), align: "right", cell: (b) => b.txCount },
              { key: "time", header: t("common.time"), cell: (b) => formatDateTime(b.blockTime, locale) },
              { key: "connected", header: t("blockchain.connected"), cell: (b) => relativeTime(b.connectedAt, locale) },
            ]}
          />
        ) : null}
        {tab === "reorgs" ? (
          <>
            <DataTable
              rows={c?.reorganizations}
              rowKey={(r) => r.id}
              onRowClick={(r) => setInspect(r as unknown as EventRow)}
              empty={{ title: t("widgets.noReorgs") }}
              columns={[
                { key: "time", header: t("common.time"), cell: (r) => formatDateTime(r.observedAt, locale) },
                { key: "depth", header: t("blockchain.depth"), align: "right", cell: (r) => String(r.payload?.depth ?? "-") },
                { key: "ancestor", header: t("blockchain.ancestor"), cell: (r) => `${String(r.payload?.ancestor_height ?? "-")}` },
                { key: "disc", header: t("blockchain.disconnected"), align: "right", cell: (r) => (r.payload?.disconnected as unknown[] | undefined)?.length ?? 0 },
                { key: "conn", header: t("blockchain.connected"), align: "right", cell: (r) => (r.payload?.connected as unknown[] | undefined)?.length ?? 0 },
                { key: "old", header: "Old tip", cell: (r) => <Hash value={String(r.payload?.old_tip ?? "")} copy={false} /> },
              ]}
            />
            <div className="px-5 pb-5 pt-2">
              <h3 className="mb-2 text-[13px] font-semibold">{t("blockchain.staleBlocks")}</h3>
              <div className="flex flex-wrap gap-2">
                {c?.staleBlocks.map((b) => (
                  <Tag key={b.hash} tone="pink" dot={false}>
                    {b.height} · {b.hash.slice(0, 10)}
                  </Tag>
                ))}
              </div>
            </div>
          </>
        ) : null}
        {tab === "events" ? (
          <DataTable
            rows={events.data?.events}
            loading={events.loading}
            rowKey={(e) => e.id}
            onRowClick={setInspect}
            columns={[
              { key: "seq", header: "#", cell: (e) => e.seq },
              { key: "type", header: t("blockchain.eventType"), primary: true, cell: (e) => <span className="font-mono text-xs">{e.eventType}</span> },
              { key: "aggregate", header: t("blockchain.aggregate"), cell: (e) => <span className="flex items-center gap-1">{e.aggregateType} <Hash value={e.aggregateId} copy={false} size={6} /></span> },
              { key: "time", header: t("common.time"), cell: (e) => formatDateTime(e.observedAt, locale) },
            ]}
            pageSize={30}
          />
        ) : null}
      </Panel>
      <Sheet open={!!inspect} onOpenChange={(o) => !o && setInspect(null)} title={inspect?.eventType ?? ""}>
        {inspect ? <EventInspector event={inspect} /> : null}
      </Sheet>
    </div>
  );
}
