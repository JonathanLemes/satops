import { useQuery } from "@apollo/client/react";
import { ArrowLeft } from "lucide-react";
import { Link, useParams } from "react-router";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { useEnvironmentId } from "@/lib/session";
import { formatDateTime, formatNumber } from "@/lib/utils";
import { DataTable } from "@/components/data/data-table";
import { Hash, Sats, Timeline } from "@/components/data/display";
import { ErrorState, KV, LoadingState, Notice, PageHeader, Panel, PanelHeader, StatusTag, Tag } from "@/components/ui/misc";

const TRANSACTION = graphql(`
  query Transaction($environmentId: ID!, $txid: String!) {
    transaction(environmentId: $environmentId, txid: $txid) {
      id
      txid
      status
      blockHash
      blockHeight
      confirmations
      feeSats
      vsize
      isCoinbase
      replacedByTxid
      conflictsWith
      firstSeenAt
      statusChangedAt
      reconciliationStatus
      outputs {
        vout
        valueSats
        address
        scriptType
        spentByTxid
        watched
      }
      inputs {
        vin
        prevTxid
        prevVout
        valueSats
        address
        watched
      }
      statusHistory {
        fromStatus
        toStatus
        blockHash
        blockHeight
        reason
        insertedAt
      }
      events {
        id
        seq
        eventType
        observedAt
        correlationId
      }
      operations {
        id
        operationId
        kind
        state
        accountRef
        amountSats
        generation
      }
    }
  }
`);

export default function TransactionDetailPage() {
  const { txid = "" } = useParams();
  const { t, tx: tr, locale } = useI18n();
  const environmentId = useEnvironmentId();
  const { data, loading, error, refetch } = useQuery(TRANSACTION, { variables: { environmentId, txid } });
  const tx = data?.transaction;

  if (loading && !data) return <LoadingState rows={8} />;
  if (error && !data) return <ErrorState onRetry={() => refetch()} />;
  if (!tx)
    return (
      <div className="flex flex-col gap-4">
        <Link to="/transactions" className="inline-flex items-center gap-2 text-sm text-text-secondary hover:text-text">
          <ArrowLeft size={16} /> {t("transactions.title")}
        </Link>
        <Notice tone="warning">{t("transactions.notFound")}</Notice>
      </div>
    );

  const watchedLabel = (w: unknown) => {
    const list = (w as { wallet: string; account_ref?: string }[] | null) ?? [];
    return list.length ? list.map((x) => <Tag key={x.wallet} tone="primary">{x.wallet}</Tag>) : null;
  };

  return (
    <div className="flex flex-col gap-5">
      <Link to="/transactions" className="inline-flex items-center gap-2 text-sm text-text-secondary hover:text-text">
        <ArrowLeft size={16} /> {t("transactions.title")}
      </Link>
      <PageHeader title={<Hash value={tx.txid} size={12} className="text-xl" />} actions={<StatusTag status={tx.status} />} />
      <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_360px]">
        <div className="flex min-w-0 flex-col gap-5">
          <Panel>
            <PanelHeader title={t("transactions.outputs")} />
            <DataTable
              rows={tx.outputs}
              rowKey={(o) => String(o.vout)}
              columns={[
                { key: "vout", header: "#", cell: (o) => o.vout },
                { key: "address", header: t("wallets.addresses"), cell: (o) => <span className="flex flex-wrap items-center gap-2"><Hash value={o.address} />{watchedLabel(o.watched)}</span> },
                { key: "value", header: t("common.amount"), align: "right", cell: (o) => <Sats value={o.valueSats} className="text-text" /> },
                { key: "spent", header: t("transactions.spentBy"), cell: (o) => (o.spentByTxid ? <Link to={`/transactions/${o.spentByTxid}`}><Hash value={o.spentByTxid} copy={false} /></Link> : "-") },
              ]}
            />
          </Panel>
          <Panel>
            <PanelHeader title={t("transactions.inputs")} />
            <DataTable
              rows={tx.inputs}
              rowKey={(i) => String(i.vin)}
              empty={{ title: tx.isCoinbase ? t("transactions.coinbase") : t("common.noResults") }}
              columns={[
                { key: "vin", header: "#", cell: (i) => i.vin },
                { key: "prev", header: "Outpoint", cell: (i) => (i.prevTxid ? <Link to={`/transactions/${i.prevTxid}`} className="font-mono text-xs hover:underline">{`${i.prevTxid.slice(0, 12)}…:${i.prevVout}`}</Link> : "-") },
                { key: "address", header: t("wallets.addresses"), cell: (i) => <span className="flex flex-wrap items-center gap-2"><Hash value={i.address} />{watchedLabel(i.watched)}</span> },
                { key: "value", header: t("common.amount"), align: "right", cell: (i) => <Sats value={i.valueSats} /> },
              ]}
            />
          </Panel>
          <Panel>
            <PanelHeader title={t("transactions.operations")} />
            <DataTable
              rows={tx.operations}
              rowKey={(o) => o.id}
              columns={[
                { key: "op", header: t("audit.operation"), cell: (o) => <Link className="font-mono text-xs hover:underline" to={`/audit?operation=${encodeURIComponent(o.operationId)}`}>{o.operationId}</Link> },
                { key: "account", header: t("wallets.accountRef"), cell: (o) => o.accountRef },
                { key: "state", header: t("common.status"), cell: (o) => <StatusTag status={o.state} /> },
                { key: "gen", header: t("ledger.generation"), align: "right", cell: (o) => o.generation },
                { key: "amount", header: t("common.amount"), align: "right", cell: (o) => <Sats value={o.amountSats} /> },
              ]}
            />
          </Panel>
        </div>
        <div className="flex flex-col gap-5">
          <Panel className="gap-2 p-5">
            <KV label={t("transactions.confirmations")} value={formatNumber(tx.confirmations, locale)} />
            <KV label={t("transactions.block")} value={tx.blockHeight ?? "-"} />
            <KV label={t("blockchain.blocks")} value={<Hash value={tx.blockHash} />} />
            <KV label={t("transactions.fee")} value={<Sats value={tx.feeSats} />} />
            <KV label={t("transactions.vsize")} value={tx.vsize ? `${tx.vsize} vB` : "-"} />
            <KV label={t("transactions.firstSeen")} value={formatDateTime(tx.firstSeenAt, locale)} />
            <KV label={t("transactions.reconciliation")} value={<StatusTag status={tx.reconciliationStatus} />} />
            {tx.replacedByTxid ? <KV label={t("transactions.replacedBy")} value={<Hash value={tx.replacedByTxid} />} /> : null}
            {tx.conflictsWith?.length ? <KV label={t("transactions.conflictsWith")} value={tx.conflictsWith.map((c) => <Hash key={c} value={c} />)} /> : null}
          </Panel>
          <Panel className="p-5">
            <h2 className="mb-4 text-base font-semibold">{t("transactions.history")}</h2>
            <Timeline
              items={tx.statusHistory.map((s, i) => ({
                id: String(i),
                title: <span className="flex items-center gap-2">{s.fromStatus ? <><StatusTag status={s.fromStatus} />→</> : null}<StatusTag status={s.toStatus} /></span>,
                time: s.insertedAt,
                description: s.reason,
                tone: s.toStatus === "confirmed" ? "success" : s.toStatus === "unconfirmed" ? "warning" : s.toStatus === "conflicted" ? "danger" : "default",
              }))}
            />
          </Panel>
          <Panel className="p-5">
            <h2 className="mb-3 text-base font-semibold">{t("transactions.events")}</h2>
            <ul className="flex flex-col gap-2 text-xs">
              {tx.events.map((e) => (
                <li key={e.id} className="flex items-center justify-between gap-2">
                  <span className="font-mono">{tr(`${e.eventType}`)}</span>
                  <span className="text-text-muted">#{e.seq}</span>
                </li>
              ))}
            </ul>
          </Panel>
        </div>
      </div>
    </div>
  );
}
