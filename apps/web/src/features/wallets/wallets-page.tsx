import { useMutation, useQuery } from "@apollo/client/react";
import { zodResolver } from "@hookform/resolvers/zod";
import { Plus, ShieldAlert, Trash2, Wallet as WalletIcon } from "lucide-react";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { Link } from "react-router";
import { toast } from "sonner";
import { z } from "zod";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { useEnvironmentId, useSession } from "@/lib/session";
import { relativeTime } from "@/lib/utils";
import { DataTable } from "@/components/data/data-table";
import { Hash, MetricCard, Sats } from "@/components/data/display";
import { Button } from "@/components/ui/button";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import { EmptyState, ErrorState, LoadingState, Notice, PageHeader, Panel, PanelHeader, Segmented, StatusTag, Tag } from "@/components/ui/misc";
import { ConfirmDialog, Sheet } from "@/components/ui/overlay";

const WALLETS = graphql(`
  query Wallets($environmentId: ID!) {
    wallets(environmentId: $environmentId) {
      id
      name
      kind
      descriptor
      groupName
      labels
      accountRef
      derivationLimit
      addresses {
        address
        label
        derivationIndex
      }
      balance {
        confirmedSats
        pendingSats
        utxoCount
      }
    }
  }
`);

const PORTFOLIO = graphql(`
  query Portfolio($environmentId: ID!) {
    portfolio(environmentId: $environmentId) {
      walletCount
      balance {
        confirmedSats
        pendingSats
        utxoCount
      }
      utxos {
        txid
        vout
        address
        valueSats
        status
        blockHeight
        spentUnconfirmed
      }
      history {
        txid
        status
        blockHeight
        firstSeenAt
        receivedSats
        sentSats
      }
      internalTransfers {
        txid
        fromWalletId
        toWalletId
        valueSats
      }
    }
  }
`);

const CREATE = graphql(`
  mutation CreateWallet($environmentId: ID!, $input: WalletInput!) {
    createWallet(environmentId: $environmentId, input: $input) {
      id
    }
  }
`);

const DELETE = graphql(`
  mutation DeleteWallet($id: ID!) {
    deleteWallet(id: $id)
  }
`);

const schema = z.object({
  name: z.string().min(1).max(80),
  kind: z.enum(["addresses", "descriptor"]),
  addresses: z.string(),
  descriptor: z.string(),
  derivationLimit: z.coerce.number().int().min(1).max(1000),
  groupName: z.string(),
  accountRef: z.string().regex(/^$|^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$/),
});
type Values = z.infer<typeof schema>;

export default function WalletsPage() {
  const { t, locale } = useI18n();
  const environmentId = useEnvironmentId();
  const { can } = useSession();
  const wallets = useQuery(WALLETS, { variables: { environmentId } });
  const portfolio = useQuery(PORTFOLIO, { variables: { environmentId } });
  const [create] = useMutation(CREATE);
  const [remove] = useMutation(DELETE);
  const [open, setOpen] = useState(false);
  const [toDelete, setToDelete] = useState<string | null>(null);
  const [tab, setTab] = useState<"wallets" | "history" | "utxos" | "transfers">("wallets");
  const names = new Map((wallets.data?.wallets ?? []).map((w) => [w.id, w.name]));

  const form = useForm<Values>({
    resolver: zodResolver(schema) as never,
    defaultValues: { name: "", kind: "addresses", addresses: "", descriptor: "", derivationLimit: 20, groupName: "", accountRef: "" },
  });
  const kind = form.watch("kind");

  const submit = form.handleSubmit(async (v) => {
    try {
      await create({
        variables: {
          environmentId,
          input: {
            name: v.name,
            kind: v.kind,
            addresses: v.kind === "addresses" ? v.addresses.split(/\s+/).filter(Boolean) : undefined,
            descriptor: v.kind === "descriptor" ? v.descriptor : undefined,
            derivationLimit: v.derivationLimit,
            groupName: v.groupName || undefined,
            accountRef: v.accountRef || undefined,
          },
        },
      });
      toast.success(t("common.saved"));
      setOpen(false);
      form.reset();
      wallets.refetch();
      portfolio.refetch();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("common.error"));
    }
  });

  const p = portfolio.data?.portfolio;

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t("wallets.title")}
        subtitle={t("wallets.subtitle")}
        actions={
          can("wallet.manage") ? (
            <Button variant="primary" onClick={() => setOpen(true)}>
              <Plus /> {t("wallets.add")}
            </Button>
          ) : null
        }
      />
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <MetricCard label={t("wallets.consolidated")} value={<Sats value={(p?.balance.confirmedSats ?? 0) + (p?.balance.pendingSats ?? 0)} />} glow="amber" />
        <MetricCard label={t("wallets.confirmed")} value={<Sats value={p?.balance.confirmedSats} />} glow="green" />
        <MetricCard label={t("wallets.pending")} value={<Sats value={p?.balance.pendingSats} />} glow="violet" />
        <MetricCard label={t("wallets.utxos")} value={p?.balance.utxoCount ?? 0} glow="blue" />
      </div>
      <p className="text-xs text-text-muted">{t("wallets.noDoubleCount")}</p>
      <Panel>
        <PanelHeader
          title={
            <Segmented
              label={t("wallets.title")}
              value={tab}
              onChange={setTab}
              options={[
                { value: "wallets", label: t("wallets.title") },
                { value: "history", label: t("wallets.history") },
                { value: "utxos", label: t("wallets.utxos") },
                { value: "transfers", label: t("wallets.transfers") },
              ]}
            />
          }
        />
        {tab === "wallets" ? (
          wallets.loading && !wallets.data ? (
            <LoadingState />
          ) : wallets.error && !wallets.data ? (
            <ErrorState onRetry={() => wallets.refetch()} />
          ) : !wallets.data?.wallets.length ? (
            <EmptyState icon={WalletIcon} title={t("wallets.empty")} description={t("wallets.emptyHint")} />
          ) : (
            <ul className="flex flex-col divide-y divide-border border-t border-border">
              {wallets.data.wallets.map((w) => (
                <li key={w.id} className="flex flex-col gap-3 px-5 py-4 md:flex-row md:items-center">
                  <div className="flex min-w-0 flex-1 flex-col gap-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="font-semibold text-text">{w.name}</span>
                      <Tag tone="neutral" dot={false}>
                        {w.kind === "descriptor" ? t("wallets.kindDescriptor") : t("wallets.kindAddresses")}
                      </Tag>
                      {w.groupName ? <Tag tone="violet">{w.groupName}</Tag> : null}
                      {w.accountRef ? <Tag tone="primary">{w.accountRef}</Tag> : null}
                    </div>
                    <span className="text-xs text-text-muted">
                      {w.addresses.length} {t("wallets.addresses").toLowerCase()}
                      {w.descriptor ? ` · ${w.descriptor.slice(0, 48)}…` : ""}
                    </span>
                  </div>
                  <div className="flex items-center gap-5 text-[13px]">
                    <span className="flex flex-col items-end">
                      <span className="text-[11px] text-text-muted">{t("wallets.confirmed")}</span>
                      <Sats value={w.balance.confirmedSats} className="font-medium text-text" />
                    </span>
                    <span className="flex flex-col items-end">
                      <span className="text-[11px] text-text-muted">{t("wallets.pending")}</span>
                      <Sats value={w.balance.pendingSats} />
                    </span>
                    {can("wallet.manage") ? (
                      <Button variant="ghost" size="icon-sm" aria-label={t("common.delete")} onClick={() => setToDelete(w.id)}>
                        <Trash2 />
                      </Button>
                    ) : null}
                  </div>
                </li>
              ))}
            </ul>
          )
        ) : null}
        {tab === "history" ? (
          <DataTable
            rows={p?.history}
            loading={portfolio.loading}
            rowKey={(r) => r.txid}
            columns={[
              { key: "txid", header: t("transactions.txid"), cell: (r) => <Link to={`/transactions/${r.txid}`}><Hash value={r.txid} copy={false} /></Link> },
              { key: "status", header: t("common.status"), cell: (r) => <StatusTag status={r.status} /> },
              { key: "received", header: t("wallets.received"), align: "right", cell: (r) => <Sats value={r.receivedSats} />, sortValue: (r) => r.receivedSats },
              { key: "sent", header: t("wallets.sent"), align: "right", cell: (r) => <Sats value={r.sentSats} />, sortValue: (r) => r.sentSats },
              { key: "seen", header: t("transactions.firstSeen"), cell: (r) => relativeTime(r.firstSeenAt, locale), sortValue: (r) => r.firstSeenAt },
            ]}
            pageSize={20}
          />
        ) : null}
        {tab === "utxos" ? (
          <DataTable
            rows={p?.utxos}
            loading={portfolio.loading}
            rowKey={(r) => `${r.txid}:${r.vout}`}
            columns={[
              { key: "outpoint", header: "Outpoint", cell: (r) => <span className="font-mono text-xs">{`${r.txid.slice(0, 10)}…:${r.vout}`}</span> },
              { key: "address", header: t("wallets.addresses"), cell: (r) => <Hash value={r.address} /> },
              { key: "value", header: t("common.amount"), align: "right", cell: (r) => <Sats value={r.valueSats} />, sortValue: (r) => r.valueSats },
              { key: "status", header: t("common.status"), cell: (r) => <StatusTag status={r.spentUnconfirmed ? "pending" : r.status} /> },
            ]}
            pageSize={20}
          />
        ) : null}
        {tab === "transfers" ? (
          <DataTable
            rows={p?.internalTransfers}
            rowKey={(r) => `${r.txid}:${r.fromWalletId}:${r.toWalletId}`}
            columns={[
              { key: "txid", header: t("transactions.txid"), cell: (r) => <Hash value={r.txid} /> },
              { key: "from", header: t("ledger.from"), cell: (r) => names.get(r.fromWalletId) ?? r.fromWalletId },
              { key: "to", header: t("ledger.to"), cell: (r) => names.get(r.toWalletId) ?? r.toWalletId },
              { key: "value", header: t("common.amount"), align: "right", cell: (r) => <Sats value={r.valueSats} /> },
            ]}
          />
        ) : null}
      </Panel>
      <Sheet
        open={open}
        onOpenChange={setOpen}
        title={t("wallets.add")}
        footer={
          <>
            <Button variant="ghost" onClick={() => setOpen(false)}>
              {t("common.cancel")}
            </Button>
            <Button variant="primary" onClick={submit} loading={form.formState.isSubmitting}>
              {t("common.save")}
            </Button>
          </>
        }
      >
        <form className="flex flex-col gap-4" onSubmit={submit}>
          <Notice tone="warning">
            <ShieldAlert size={16} className="mt-0.5 shrink-0" />
            {t("wallets.sensitive")}
          </Notice>
          <Field label={t("common.name")} required error={form.formState.errors.name ? t("validation.required") : undefined}>
            {(id) => <Input id={id} {...form.register("name")} />}
          </Field>
          <Field label={t("wallets.kind")}>
            {(id) => (
              <Select id={id} {...form.register("kind")}>
                <option value="addresses">{t("wallets.kindAddresses")}</option>
                <option value="descriptor">{t("wallets.kindDescriptor")}</option>
              </Select>
            )}
          </Field>
          {kind === "addresses" ? (
            <Field label={t("wallets.addresses")} hint={t("wallets.addressesHint")}>
              {(id, d) => <Textarea id={id} aria-describedby={d} className="font-mono text-xs" {...form.register("addresses")} />}
            </Field>
          ) : (
            <>
              <Field label={t("wallets.descriptor")} hint={t("wallets.descriptorHint")}>
                {(id, d) => <Textarea id={id} aria-describedby={d} className="font-mono text-xs" {...form.register("descriptor")} />}
              </Field>
              <Field label={t("wallets.derivationLimit")}>{(id) => <Input id={id} type="number" min={1} max={1000} {...form.register("derivationLimit")} />}</Field>
            </>
          )}
          <Field label={t("wallets.group")}>{(id) => <Input id={id} {...form.register("groupName")} />}</Field>
          <Field label={t("wallets.accountRef")} hint={t("wallets.accountRefHint")} error={form.formState.errors.accountRef ? t("validation.slug") : undefined}>
            {(id, d) => <Input id={id} aria-describedby={d} {...form.register("accountRef")} />}
          </Field>
        </form>
      </Sheet>
      <ConfirmDialog
        open={!!toDelete}
        onOpenChange={(o) => !o && setToDelete(null)}
        title={t("common.delete")}
        description={t("wallets.deleteConfirm")}
        danger
        onConfirm={async () => {
          if (toDelete) await remove({ variables: { id: toDelete } });
          wallets.refetch();
          portfolio.refetch();
        }}
      />
    </div>
  );
}
