import { useMutation, useQuery } from "@apollo/client/react";
import { zodResolver } from "@hookform/resolvers/zod";
import { ArrowRightLeft, CheckCircle2, ShieldAlert, Undo2 } from "lucide-react";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { Link } from "react-router";
import { toast } from "sonner";
import { z } from "zod";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { useEnvironmentId, useSession } from "@/lib/session";
import { formatDateTime } from "@/lib/utils";
import { DataTable } from "@/components/data/data-table";
import { JsonView, MetricCard, Sats } from "@/components/data/display";
import { Button } from "@/components/ui/button";
import { Field, Input, Select } from "@/components/ui/input";
import { Notice, PageHeader, Panel, PanelHeader, Segmented, StatusTag, Tag } from "@/components/ui/misc";
import { ConfirmDialog, Sheet } from "@/components/ui/overlay";

const LEDGER = graphql(`
  query LedgerAccounts($environmentId: ID!) {
    ledgerAccounts(environmentId: $environmentId) {
      id
      code
      type
      normalBalance
      restricted
      ownerRef
      balanceSats
      debitTotal
      creditTotal
    }
    ledgerInvariants(environmentId: $environmentId) {
      ok
      balanced
      totalDebits
      totalCredits
      unbalancedJournals
      projectionDrift
      negativeRestricted
      duplicateCredits
    }
    financialRules {
      name
      version
      current
    }
    customerBalances(environmentId: $environmentId) {
      accountRef
      availableSats
      pendingSats
      reservedSats
    }
  }
`);

const JOURNALS = graphql(`
  query Journals($environmentId: ID!) {
    journals(environmentId: $environmentId, limit: 100) {
      id
      operationId
      entryKind
      ruleName
      ruleVersion
      description
      reversesJournalId
      postedAt
      metadata
      postings {
        id
        accountCode
        direction
        amountSats
      }
    }
  }
`);

const OPERATIONS = graphql(`
  query LedgerOperations($environmentId: ID!) {
    ledgerOperations(environmentId: $environmentId, limit: 200) {
      id
      operationId
      kind
      state
      accountRef
      amountSats
      feeSats
      txid
      generation
      updatedAt
    }
  }
`);

const COMPENSATE = graphql(`
  mutation CompensateJournal($environmentId: ID!, $journalId: ID!, $reason: String!) {
    compensateJournal(environmentId: $environmentId, journalId: $journalId, reason: $reason) {
      status
    }
  }
`);

const WITHDRAW = graphql(`
  mutation RequestWithdrawal($environmentId: ID!, $accountRef: String!, $amountSats: Sats!, $idempotencyKey: String!) {
    requestWithdrawal(
      environmentId: $environmentId
      accountRef: $accountRef
      amountSats: $amountSats
      idempotencyKey: $idempotencyKey
    ) {
      status
    }
  }
`);

const TRANSFER = graphql(`
  mutation InternalTransfer(
    $environmentId: ID!
    $fromRef: String!
    $toRef: String!
    $amountSats: Sats!
    $idempotencyKey: String!
  ) {
    internalTransfer(
      environmentId: $environmentId
      fromRef: $fromRef
      toRef: $toRef
      amountSats: $amountSats
      idempotencyKey: $idempotencyKey
    ) {
      status
    }
  }
`);

type Tab = "accounts" | "balances" | "journals" | "operations" | "rules";

const opSchema = z.object({
  type: z.enum(["withdrawal", "transfer"]),
  from: z.string().min(1),
  to: z.string(),
  amount: z.coerce.number().int().positive(),
  key: z.string().min(1),
});

export default function LedgerPage() {
  const { t, locale } = useI18n();
  const environmentId = useEnvironmentId();
  const { can } = useSession();
  const [tab, setTab] = useState<Tab>("accounts");
  const ledger = useQuery(LEDGER, { variables: { environmentId } });
  const journals = useQuery(JOURNALS, { variables: { environmentId }, skip: tab !== "journals" });
  const operations = useQuery(OPERATIONS, { variables: { environmentId }, skip: tab !== "operations" });
  const [compensate] = useMutation(COMPENSATE);
  const [withdraw] = useMutation(WITHDRAW);
  const [transfer] = useMutation(TRANSFER);
  const [toCompensate, setToCompensate] = useState<string | null>(null);
  const [journal, setJournal] = useState<string | null>(null);
  const [opOpen, setOpOpen] = useState(false);
  const inv = ledger.data?.ledgerInvariants;
  const selectedJournal = journals.data?.journals.find((j) => j.id === journal);
  const form = useForm<z.infer<typeof opSchema>>({
    resolver: zodResolver(opSchema) as never,
    defaultValues: { type: "withdrawal", from: "", to: "", amount: 1000, key: "" },
  });
  const opType = form.watch("type");

  const submitOp = form.handleSubmit(async (v) => {
    try {
      const r =
        v.type === "withdrawal"
          ? (
              await withdraw({
                variables: { environmentId, accountRef: v.from, amountSats: v.amount, idempotencyKey: v.key },
              })
            ).data?.requestWithdrawal?.status
          : (
              await transfer({
                variables: { environmentId, fromRef: v.from, toRef: v.to, amountSats: v.amount, idempotencyKey: v.key },
              })
            ).data?.internalTransfer?.status;
      toast.success(`${t("common.saved")} (${r})`);
      setOpOpen(false);
      ledger.refetch();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("common.error"));
    }
  });

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t("ledger.title")}
        subtitle={t("ledger.subtitle")}
        actions={
          can("ledger.post") ? (
            <Button onClick={() => setOpOpen(true)}>
              <ArrowRightLeft /> {t("ledger.withdraw")} / {t("ledger.transfer")}
            </Button>
          ) : null
        }
      />
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <MetricCard
          label={t("ledger.invariants")}
          value={inv?.ok ? t("common.yes") : t("common.no")}
          hint={inv?.ok ? t("ledger.ok") : t("ledger.violated")}
          glow={inv?.ok ? "green" : "red"}
        />
        <MetricCard label={t("ledger.debits")} value={<Sats value={inv?.totalDebits} />} glow="blue" />
        <MetricCard label={t("ledger.credits")} value={<Sats value={inv?.totalCredits} />} glow="violet" />
        <MetricCard
          label={t("ledger.duplicates")}
          value={inv?.duplicateCredits ?? 0}
          glow={inv?.duplicateCredits ? "red" : "green"}
        />
      </div>
      {inv && !inv.ok ? (
        <Notice tone="danger">
          <ShieldAlert size={16} className="mt-0.5 shrink-0" />
          <JsonView
            value={{ unbalanced: inv.unbalancedJournals, drift: inv.projectionDrift, negative: inv.negativeRestricted }}
            className="w-full bg-transparent"
          />
        </Notice>
      ) : inv ? (
        <p className="flex items-center gap-2 text-xs text-success">
          <CheckCircle2 size={14} /> {t("ledger.balanced")}
        </p>
      ) : null}
      <Panel>
        <PanelHeader
          title={
            <Segmented
              label={t("ledger.title")}
              value={tab}
              onChange={setTab}
              options={[
                { value: "accounts", label: t("ledger.accounts") },
                { value: "balances", label: t("ledger.customerBalances") },
                { value: "journals", label: t("ledger.journals") },
                { value: "operations", label: t("ledger.operations") },
                { value: "rules", label: t("ledger.rules") },
              ]}
            />
          }
        />
        {tab === "accounts" ? (
          <DataTable
            rows={ledger.data?.ledgerAccounts}
            loading={ledger.loading}
            rowKey={(a) => a.id}
            columns={[
              {
                key: "code",
                header: t("ledger.code"),
                primary: true,
                cell: (a) => <span className="font-mono text-xs">{a.code}</span>,
                sortValue: (a) => a.code,
              },
              { key: "type", header: t("common.type"), cell: (a) => a.type },
              {
                key: "restricted",
                header: t("ledger.restricted"),
                cell: (a) =>
                  a.restricted ? (
                    <Tag tone="info" dot={false}>
                      {t("common.yes")}
                    </Tag>
                  ) : (
                    ""
                  ),
              },
              { key: "debits", header: t("ledger.debits"), align: "right", cell: (a) => <Sats value={a.debitTotal} /> },
              {
                key: "credits",
                header: t("ledger.credits"),
                align: "right",
                cell: (a) => <Sats value={a.creditTotal} />,
              },
              {
                key: "balance",
                header: t("ledger.balance"),
                align: "right",
                cell: (a) => <Sats value={a.balanceSats} className="font-medium text-text" />,
                sortValue: (a) => a.balanceSats,
              },
            ]}
            pageSize={40}
          />
        ) : null}
        {tab === "balances" ? (
          <DataTable
            rows={ledger.data?.customerBalances}
            rowKey={(b) => b.accountRef}
            columns={[
              { key: "ref", header: t("wallets.accountRef"), primary: true, cell: (b) => b.accountRef },
              {
                key: "available",
                header: t("status.available"),
                align: "right",
                cell: (b) => <Sats value={b.availableSats} />,
                sortValue: (b) => b.availableSats,
              },
              {
                key: "pending",
                header: t("status.pending"),
                align: "right",
                cell: (b) => <Sats value={b.pendingSats} />,
              },
              {
                key: "reserved",
                header: t("status.reserved"),
                align: "right",
                cell: (b) => <Sats value={b.reservedSats} />,
              },
            ]}
          />
        ) : null}
        {tab === "journals" ? (
          <DataTable
            rows={journals.data?.journals}
            loading={journals.loading}
            rowKey={(j) => j.id}
            onRowClick={(j) => setJournal(j.id)}
            columns={[
              { key: "time", header: t("ledger.posted"), cell: (j) => formatDateTime(j.postedAt, locale) },
              {
                key: "op",
                header: t("audit.operation"),
                primary: true,
                cell: (j) => <span className="font-mono text-[11px]">{j.operationId.slice(0, 40)}</span>,
              },
              {
                key: "kind",
                header: t("ledger.entryKind"),
                cell: (j) => (j.reversesJournalId ? <Tag tone="pink">{j.entryKind.split(":")[0]}</Tag> : j.entryKind),
              },
              { key: "rule", header: t("ledger.rule"), cell: (j) => `${j.ruleName} v${j.ruleVersion}` },
              {
                key: "amount",
                header: t("common.amount"),
                align: "right",
                cell: (j) => (
                  <Sats
                    value={j.postings.filter((p) => p.direction === "debit").reduce((s, p) => s + p.amountSats, 0)}
                  />
                ),
              },
            ]}
            pageSize={30}
          />
        ) : null}
        {tab === "operations" ? (
          <DataTable
            rows={operations.data?.ledgerOperations}
            loading={operations.loading}
            rowKey={(o) => o.id}
            columns={[
              {
                key: "op",
                header: t("audit.operation"),
                primary: true,
                cell: (o) => (
                  <Link
                    className="font-mono text-[11px] hover:underline"
                    to={`/audit?operation=${encodeURIComponent(o.operationId)}`}
                  >
                    {o.operationId.slice(0, 48)}
                  </Link>
                ),
              },
              { key: "kind", header: t("common.kind"), cell: (o) => o.kind },
              { key: "state", header: t("common.status"), cell: (o) => <StatusTag status={o.state} /> },
              { key: "ref", header: t("wallets.accountRef"), cell: (o) => o.accountRef },
              { key: "gen", header: t("ledger.generation"), align: "right", cell: (o) => o.generation },
              { key: "amount", header: t("common.amount"), align: "right", cell: (o) => <Sats value={o.amountSats} /> },
            ]}
            pageSize={30}
          />
        ) : null}
        {tab === "rules" ? (
          <DataTable
            rows={ledger.data?.financialRules}
            rowKey={(r) => `${r.name}@${r.version}`}
            columns={[
              {
                key: "name",
                header: t("ledger.rule"),
                primary: true,
                cell: (r) => <span className="font-mono text-xs">{r.name}</span>,
              },
              { key: "version", header: t("ledger.version"), align: "right", cell: (r) => r.version },
              {
                key: "current",
                header: t("ledger.current"),
                cell: (r) => (r.current ? <StatusTag status="applied" /> : ""),
              },
            ]}
          />
        ) : null}
      </Panel>
      <Sheet
        open={!!selectedJournal}
        onOpenChange={(o) => !o && setJournal(null)}
        title={selectedJournal?.entryKind ?? ""}
        description={selectedJournal?.description ?? undefined}
      >
        {selectedJournal ? (
          <div className="flex flex-col gap-4">
            <table className="data-table">
              <thead>
                <tr>
                  <th>{t("ledger.code")}</th>
                  <th className="text-right">{t("ledger.debit")}</th>
                  <th className="text-right">{t("ledger.credit")}</th>
                </tr>
              </thead>
              <tbody>
                {selectedJournal.postings.map((p) => (
                  <tr key={p.id}>
                    <td className="font-mono text-[11px]">{p.accountCode}</td>
                    <td className="text-right">{p.direction === "debit" ? <Sats value={p.amountSats} /> : ""}</td>
                    <td className="text-right">{p.direction === "credit" ? <Sats value={p.amountSats} /> : ""}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <JsonView value={selectedJournal.metadata} />
            {can("ledger.compensate") && !selectedJournal.reversesJournalId ? (
              <>
                <Notice tone="info">{t("ledger.compensateHint")}</Notice>
                <Button variant="danger" onClick={() => setToCompensate(selectedJournal.id)}>
                  <Undo2 /> {t("ledger.compensate")}
                </Button>
              </>
            ) : null}
          </div>
        ) : null}
      </Sheet>
      <ConfirmDialog
        open={!!toCompensate}
        onOpenChange={(o) => !o && setToCompensate(null)}
        title={t("ledger.compensate")}
        description={t("ledger.compensateHint")}
        requireReason={t("common.reason")}
        danger
        onConfirm={async (reason) => {
          try {
            await compensate({ variables: { environmentId, journalId: toCompensate!, reason } });
            toast.success(t("ledger.compensated"));
            journals.refetch();
            ledger.refetch();
          } catch (e) {
            toast.error(e instanceof Error ? e.message : t("common.error"));
          }
        }}
      />
      <Sheet
        open={opOpen}
        onOpenChange={setOpOpen}
        title={`${t("ledger.withdraw")} / ${t("ledger.transfer")}`}
        footer={
          <Button variant="primary" onClick={submitOp} loading={form.formState.isSubmitting}>
            {t("common.confirm")}
          </Button>
        }
      >
        <form className="flex flex-col gap-4" onSubmit={submitOp}>
          <Field label={t("common.type")}>
            {(id) => (
              <Select id={id} {...form.register("type")}>
                <option value="withdrawal">{t("ledger.withdraw")}</option>
                <option value="transfer">{t("ledger.transfer")}</option>
              </Select>
            )}
          </Field>
          <Field label={t("ledger.from")} error={form.formState.errors.from ? t("validation.required") : undefined}>
            {(id) => <Input id={id} {...form.register("from")} />}
          </Field>
          {opType === "transfer" ? (
            <Field label={t("ledger.to")}>{(id) => <Input id={id} {...form.register("to")} />}</Field>
          ) : null}
          <Field
            label={`${t("common.amount")} (sats)`}
            error={form.formState.errors.amount ? t("validation.positiveInteger") : undefined}
          >
            {(id) => <Input id={id} type="number" min={1} step={1} {...form.register("amount")} />}
          </Field>
          <Field
            label={t("ledger.idempotencyKey")}
            error={form.formState.errors.key ? t("validation.required") : undefined}
          >
            {(id) => <Input id={id} {...form.register("key")} />}
          </Field>
        </form>
      </Sheet>
    </div>
  );
}
