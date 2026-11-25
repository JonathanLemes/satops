import { useQuery } from "@apollo/client/react";
import { useState } from "react";
import { useNavigate } from "react-router";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { useEnvironmentId } from "@/lib/session";
import { formatNumber, relativeTime } from "@/lib/utils";
import { DataTable } from "@/components/data/data-table";
import { Hash, Sats } from "@/components/data/display";
import { Checkbox, Input, Select } from "@/components/ui/input";
import { Notice, PageHeader, Panel, StatusTag } from "@/components/ui/misc";

const TRANSACTIONS = graphql(`
  query Transactions($environmentId: ID!, $filter: TransactionFilter, $after: String) {
    transactions(environmentId: $environmentId, filter: $filter, first: 30, after: $after) {
      nodes {
        id
        txid
        status
        blockHeight
        confirmations
        feeSats
        totalOutSats
        firstSeenAt
        isCoinbase
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
`);

const STATUSES = ["", "pending", "confirmed", "unconfirmed", "conflicted", "replaced", "unknown"];

export default function TransactionsPage() {
  const { t, locale } = useI18n();
  const environmentId = useEnvironmentId();
  const navigate = useNavigate();
  const [status, setStatus] = useState("");
  const [search, setSearch] = useState("");
  const [address, setAddress] = useState("");
  const [watchedOnly, setWatchedOnly] = useState(false);
  const [includeCoinbase, setIncludeCoinbase] = useState(false);
  const filter = {
    status: status || undefined,
    search: search || undefined,
    address: address || undefined,
    watchedOnly,
    includeCoinbase,
  };
  const { data, loading, error, refetch, fetchMore } = useQuery(TRANSACTIONS, { variables: { environmentId, filter } });
  const [loadingMore, setLoadingMore] = useState(false);
  const conn = data?.transactions;

  return (
    <div className="flex flex-col gap-5">
      <PageHeader title={t("transactions.title")} subtitle={t("transactions.subtitle")} />
      <Notice tone="info">{t("transactions.reorgNote")}</Notice>
      <Panel>
        <div className="flex flex-wrap items-center gap-3 p-4">
          <Input
            aria-label={t("transactions.searchPlaceholder")}
            placeholder={t("transactions.searchPlaceholder")}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-64"
          />
          <Input
            aria-label={t("transactions.addressPlaceholder")}
            placeholder={t("transactions.addressPlaceholder")}
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            className="w-64"
          />
          <Select
            aria-label={t("common.status")}
            value={status}
            onChange={(e) => setStatus(e.target.value)}
            className="w-44"
          >
            {STATUSES.map((s) => (
              <option key={s} value={s}>
                {s ? t(`status.${s}` as "status.pending") : t("common.all")}
              </option>
            ))}
          </Select>
          <Checkbox checked={watchedOnly} onChange={setWatchedOnly} label={t("transactions.watchedOnly")} />
          <Checkbox checked={includeCoinbase} onChange={setIncludeCoinbase} label={t("transactions.includeCoinbase")} />
        </div>
        <DataTable
          rows={conn?.nodes}
          loading={loading}
          error={error}
          onRetry={() => refetch()}
          rowKey={(r) => r.id}
          onRowClick={(r) => navigate(`/transactions/${r.txid}`)}
          caption={t("transactions.title")}
          columns={[
            { key: "txid", header: t("transactions.txid"), primary: true, cell: (r) => <Hash value={r.txid} /> },
            { key: "status", header: t("common.status"), cell: (r) => <StatusTag status={r.status} /> },
            {
              key: "confs",
              header: t("transactions.confirmations"),
              align: "right",
              cell: (r) => formatNumber(r.confirmations, locale),
              sortValue: (r) => r.confirmations,
            },
            {
              key: "block",
              header: t("transactions.block"),
              align: "right",
              cell: (r) => formatNumber(r.blockHeight, locale),
              sortValue: (r) => r.blockHeight,
            },
            {
              key: "amount",
              header: t("transactions.total"),
              align: "right",
              cell: (r) => <Sats value={r.totalOutSats} />,
              sortValue: (r) => r.totalOutSats,
            },
            {
              key: "fee",
              header: t("transactions.fee"),
              align: "right",
              cell: (r) => (r.isCoinbase ? t("transactions.coinbase") : <Sats value={r.feeSats} />),
            },
            {
              key: "seen",
              header: t("transactions.firstSeen"),
              cell: (r) => relativeTime(r.firstSeenAt, locale),
              sortValue: (r) => r.firstSeenAt,
            },
          ]}
          hasMore={conn?.pageInfo.hasNextPage}
          loadingMore={loadingMore}
          onLoadMore={async () => {
            setLoadingMore(true);
            await fetchMore({
              variables: { after: conn?.pageInfo.endCursor },
              updateQuery: (prev, { fetchMoreResult }) =>
                fetchMoreResult
                  ? {
                      transactions: {
                        ...fetchMoreResult.transactions,
                        nodes: [...prev.transactions.nodes, ...fetchMoreResult.transactions.nodes],
                      },
                    }
                  : prev,
            }).finally(() => setLoadingMore(false));
          }}
        />
      </Panel>
    </div>
  );
}
