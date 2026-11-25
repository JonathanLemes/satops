import { useMutation, useQuery } from "@apollo/client/react";
import { AlertTriangle, RefreshCw, Server } from "lucide-react";
import { CartesianGrid, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { toast } from "sonner";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { useEnvironmentId, useSession } from "@/lib/session";
import { formatNumber, formatTime, relativeTime } from "@/lib/utils";
import { Hash, Timeline } from "@/components/data/display";
import { Button } from "@/components/ui/button";
import {
  EmptyState,
  ErrorState,
  KV,
  LoadingState,
  Notice,
  PageHeader,
  Panel,
  PanelHeader,
  StatusTag,
  Tag,
} from "@/components/ui/misc";

const NODES = graphql(`
  query Nodes($environmentId: ID!) {
    nodes(environmentId: $environmentId) {
      isReference
      integration {
        id
        name
        status
        config
        lastError
        lastSyncAt
      }
      latest {
        reachable
        chain
        height
        bestHash
        chainwork
        peers
        mempoolSize
        rpcLatencyMs
        observedAt
        error
        initialBlockDownload
      }
      history(limit: 60) {
        observedAt
        height
        rpcLatencyMs
        reachable
      }
      downtime {
        id
        eventType
        observedAt
        payload
      }
      zmq {
        lastSequence
        gapsTotal
        duplicatesTotal
        updatedAt
      }
    }
    chainOverview(environmentId: $environmentId) {
      diverged
      referenceNode
      tip {
        height
        hash
      }
    }
  }
`);

const SYNC = graphql(`
  mutation SyncChain($environmentId: ID!) {
    syncChain(environmentId: $environmentId)
  }
`);

const tooltipStyle = { background: "var(--surface)", border: "1px solid var(--border)", borderRadius: 8, fontSize: 12 };

export default function NodesPage() {
  const { t, locale } = useI18n();
  const environmentId = useEnvironmentId();
  const { can } = useSession();
  const { data, loading, error, refetch } = useQuery(NODES, { variables: { environmentId }, pollInterval: 15_000 });
  const [sync] = useMutation(SYNC);

  if (loading && !data) return <LoadingState rows={8} />;
  if (error && !data) return <ErrorState onRetry={() => refetch()} />;
  const nodes = data?.nodes ?? [];
  const tip = data?.chainOverview.tip;

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t("nodes.title")}
        subtitle={t("nodes.subtitle")}
        actions={
          can("integration.manage") ? (
            <Button
              onClick={async () => {
                await sync({ variables: { environmentId } });
                toast.success(t("nodes.syncQueued"));
              }}
            >
              <RefreshCw /> {t("nodes.syncNow")}
            </Button>
          ) : null
        }
      />
      {data?.chainOverview.diverged ? (
        <Notice tone="warning">
          <AlertTriangle size={16} className="mt-0.5 shrink-0" />
          {t("nodes.diverged")}
        </Notice>
      ) : null}
      <p className="text-xs text-text-muted">{t("nodes.policyNote")}</p>
      {!nodes.length ? <EmptyState icon={Server} title={t("common.noResults")} /> : null}
      <Panel className="p-5">
        <h2 className="mb-4 text-base font-semibold">{t("nodes.topology")}</h2>
        <div className="flex flex-wrap items-center gap-4">
          <div className="flex flex-col items-center gap-1 rounded-lg bg-primary-soft px-4 py-3 text-center">
            <span className="text-[11px] text-primary-soft-foreground">SatOps</span>
            <span className="text-sm font-semibold">
              {t("blockchain.tip")} {formatNumber(tip?.height, locale)}
            </span>
          </div>
          {nodes.map((n) => (
            <div key={n.integration.id} className="flex items-center gap-4">
              <span
                aria-hidden
                className={
                  n.latest?.reachable ? "h-px w-10 bg-success" : "h-px w-10 border-t border-dashed border-danger"
                }
              />
              <div className="flex flex-col items-center gap-1 rounded-lg border border-border px-4 py-3 text-center">
                <span className="text-sm font-semibold">{n.integration.name}</span>
                <StatusTag status={n.latest?.reachable ? "healthy" : "unavailable"} />
                <span className="text-[11px] text-text-muted">
                  {formatNumber(n.latest?.height, locale)} · {n.latest?.peers ?? 0} peers
                </span>
              </div>
            </div>
          ))}
        </div>
      </Panel>
      <div className="grid gap-5 xl:grid-cols-2">
        {nodes.map((n) => {
          const synced =
            n.latest?.height !== null &&
            n.latest?.height !== undefined &&
            tip?.height === n.latest.height &&
            tip?.hash === n.latest.bestHash;
          const history = [...n.history].reverse().map((h) => ({
            time: formatTime(h.observedAt, locale).slice(0, 5),
            latency: h.rpcLatencyMs ?? null,
            height: h.height,
          }));
          return (
            <Panel key={n.integration.id}>
              <PanelHeader
                title={
                  <span className="flex items-center gap-2">
                    {n.integration.name}
                    {n.isReference ? <Tag tone="primary">{t("nodes.reference")}</Tag> : null}
                  </span>
                }
                subtitle={`${String(n.integration.config?.host ?? "")}:${String(n.integration.config?.port ?? "")}`}
                actions={<StatusTag status={n.latest?.reachable ? "healthy" : "unavailable"} />}
              />
              <div className="grid gap-x-8 gap-y-2 px-5 pb-4 sm:grid-cols-2">
                <KV label={t("nodes.height")} value={formatNumber(n.latest?.height, locale)} />
                <KV label={t("nodes.sync")} value={<StatusTag status={synced ? "complete" : "pending"} />} />
                <KV label={t("nodes.bestHash")} value={<Hash value={n.latest?.bestHash} />} />
                <KV label={t("nodes.peers")} value={n.latest?.peers ?? "-"} />
                <KV label={t("nodes.mempool")} value={n.latest?.mempoolSize ?? "-"} />
                <KV
                  label={t("nodes.latency")}
                  value={
                    n.latest?.rpcLatencyMs !== null && n.latest?.rpcLatencyMs !== undefined
                      ? `${n.latest.rpcLatencyMs} ms`
                      : "-"
                  }
                />
                <KV label={t("nodes.lastSeen")} value={relativeTime(n.latest?.observedAt, locale)} />
                <KV label="Chain" value={n.latest?.chain ?? "-"} />
                <KV label={`${t("nodes.zmq")} ${t("nodes.gaps")}`} value={n.zmq?.gapsTotal ?? 0} />
                <KV label={`${t("nodes.zmq")} ${t("nodes.duplicates")}`} value={n.zmq?.duplicatesTotal ?? 0} />
              </div>
              {n.latest?.error ? <p className="px-5 pb-3 text-xs text-danger">{n.latest.error}</p> : null}
              <div className="h-40 px-3">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={history} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
                    <CartesianGrid stroke="var(--border)" vertical={false} />
                    <XAxis
                      dataKey="time"
                      tick={{ fontSize: 11, fill: "var(--text-muted)" }}
                      tickLine={false}
                      axisLine={false}
                    />
                    <YAxis
                      tick={{ fontSize: 11, fill: "var(--text-muted)" }}
                      tickLine={false}
                      axisLine={false}
                      unit="ms"
                      width={48}
                    />
                    <Tooltip contentStyle={tooltipStyle} />
                    <Line
                      type="monotone"
                      dataKey="latency"
                      stroke="var(--chart-1)"
                      dot={false}
                      strokeWidth={2}
                      connectNulls={false}
                    />
                  </LineChart>
                </ResponsiveContainer>
              </div>
              <div className="px-5 pb-5 pt-2">
                <h3 className="mb-3 text-[13px] font-semibold">{t("nodes.downtime")}</h3>
                {n.downtime.length ? (
                  <Timeline
                    items={n.downtime.map((d) => ({
                      id: d.id,
                      title: d.eventType,
                      time: d.observedAt,
                      tone: d.eventType === "node.disconnected" ? "danger" : "success",
                      description: d.payload?.error ? String(d.payload.error) : null,
                    }))}
                  />
                ) : (
                  <p className="text-xs text-text-muted">{t("common.noResults")}</p>
                )}
              </div>
            </Panel>
          );
        })}
      </div>
    </div>
  );
}
