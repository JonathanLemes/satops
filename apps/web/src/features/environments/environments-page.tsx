import { useMutation, useQuery } from "@apollo/client/react";
import { FileCode2, Plus, ShieldCheck } from "lucide-react";
import { useState } from "react";
import { Link } from "react-router";
import { toast } from "sonner";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { useSession } from "@/lib/session";
import { formatDateTime } from "@/lib/utils";
import { DataTable } from "@/components/data/data-table";
import { Button } from "@/components/ui/button";
import { Field, Input } from "@/components/ui/input";
import { Notice, PageHeader, Panel, StatusTag, Tag } from "@/components/ui/misc";
import { Sheet } from "@/components/ui/overlay";

const ENVIRONMENTS = graphql(`
  query Environments {
    environments {
      id
      slug
      name
      kind
      network
      status
      requiredConfirmations
      settings
      insertedAt
    }
  }
`);

const CREATE = graphql(`
  mutation CreateEnvironment($slug: String!, $name: String!, $requiredConfirmations: Int) {
    createEnvironment(slug: $slug, name: $name, requiredConfirmations: $requiredConfirmations) {
      id
    }
  }
`);

export default function EnvironmentsPage() {
  const { t, locale } = useI18n();
  const { can, refresh, environment, setEnvironmentId } = useSession();
  const { data, loading, refetch } = useQuery(ENVIRONMENTS);
  const [create, state] = useMutation(CREATE);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ slug: "", name: "", requiredConfirmations: 3 });

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t("environments.title")}
        subtitle={t("environments.subtitle")}
        actions={
          <>
            <Link to="/engineering/configuration?kind=Environment">
              <Button>
                <FileCode2 /> {t("integrations.editAsCode")}
              </Button>
            </Link>
            {can("environment.manage") ? (
              <Button variant="primary" onClick={() => setOpen(true)}>
                <Plus /> {t("environments.create")}
              </Button>
            ) : null}
          </>
        }
      />
      <Notice tone="success">
        <ShieldCheck size={16} className="mt-0.5 shrink-0" />
        {t("environments.regtestOnly")}
      </Notice>
      <Panel>
        <DataTable
          rows={data?.environments}
          loading={loading}
          rowKey={(e) => e.id}
          onRowClick={(e) => setEnvironmentId(e.id)}
          columns={[
            { key: "name", header: t("common.name"), primary: true, cell: (e) => <span className="flex items-center gap-2">{e.name}{e.id === environment?.id ? <Tag tone="primary">{t("nodes.reference")}</Tag> : null}</span> },
            { key: "slug", header: t("environments.slug"), cell: (e) => <span className="font-mono text-xs">{e.slug}</span> },
            { key: "kind", header: t("environments.kind"), cell: (e) => e.kind },
            { key: "network", header: t("environments.network"), cell: (e) => <Tag tone="warning">{e.network}</Tag> },
            { key: "confs", header: t("environments.confirmations"), align: "right", cell: (e) => e.requiredConfirmations },
            { key: "status", header: t("common.status"), cell: (e) => <StatusTag status={e.status === "active" ? "healthy" : "skipped"} /> },
            { key: "created", header: t("common.created"), cell: (e) => formatDateTime(e.insertedAt, locale) },
          ]}
        />
      </Panel>
      <p className="text-xs text-text-muted">{t("environments.manageAsCode")}</p>
      <Sheet
        open={open}
        onOpenChange={setOpen}
        title={t("environments.create")}
        footer={
          <Button
            variant="primary"
            loading={state.loading}
            onClick={async () => {
              try {
                await create({ variables: form });
                setOpen(false);
                await refresh();
                refetch();
                toast.success(t("common.saved"));
              } catch (e) {
                toast.error(e instanceof Error ? e.message : t("common.error"));
              }
            }}
          >
            {t("common.create")}
          </Button>
        }
      >
        <div className="flex flex-col gap-4">
          <Field label={t("environments.slug")} hint={t("validation.slug")}>{(id) => <Input id={id} value={form.slug} onChange={(e) => setForm({ ...form, slug: e.target.value })} />}</Field>
          <Field label={t("common.name")}>{(id) => <Input id={id} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />}</Field>
          <Field label={t("environments.confirmations")}>
            {(id) => <Input id={id} type="number" min={1} max={100} value={form.requiredConfirmations} onChange={(e) => setForm({ ...form, requiredConfirmations: Number(e.target.value) })} />}
          </Field>
        </div>
      </Sheet>
    </div>
  );
}
