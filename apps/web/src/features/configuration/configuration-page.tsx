import { useQuery } from "@apollo/client/react";
import { Plus } from "lucide-react";
import { Link, useNavigate, useSearchParams } from "react-router";
import { graphql } from "@/gql";
import { useI18n } from "@/i18n";
import { useSession } from "@/lib/session";
import { relativeTime } from "@/lib/utils";
import { DataTable } from "@/components/data/data-table";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/input";
import { Notice, PageHeader, Panel, StatusTag, Tag } from "@/components/ui/misc";
import { KINDS } from "./schema";

const RESOURCES = graphql(`
  query ConfigResources($kind: String) {
    configResources(kind: $kind) {
      id
      kind
      name
      environmentRef
      desiredRevision
      appliedRevision
      status
      statusMessage
      updatedAt
    }
  }
`);

export default function ConfigurationPage() {
  const { t, locale } = useI18n();
  const { can } = useSession();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const kind = params.get("kind") ?? "";
  const { data, loading, error, refetch } = useQuery(RESOURCES, { variables: { kind: kind || null } });

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t("config.title")}
        subtitle={t("config.subtitle")}
        actions={
          can("config.apply") ? (
            <Link to={`/engineering/configuration/new${kind ? `?kind=${kind}` : ""}`}>
              <Button variant="primary">
                <Plus /> {t("config.new")}
              </Button>
            </Link>
          ) : null
        }
      />
      <Notice tone="info">{t("config.reapplyNote")}</Notice>
      <Panel>
        <div className="flex items-center gap-3 p-4">
          <Select aria-label={t("config.kindLabel")} value={kind} onChange={(e) => setParams(e.target.value ? { kind: e.target.value } : {})} className="w-60">
            <option value="">{t("common.all")}</option>
            {KINDS.map((k) => (
              <option key={k} value={k}>
                {k}
              </option>
            ))}
          </Select>
        </div>
        <DataTable
          rows={data?.configResources}
          loading={loading}
          error={error}
          onRetry={() => refetch()}
          rowKey={(r) => r.id}
          onRowClick={(r) => navigate(`/engineering/configuration/${r.kind}/${r.name}`)}
          columns={[
            { key: "kind", header: t("config.kindLabel"), cell: (r) => <Tag tone="neutral" dot={false}>{r.kind}</Tag>, sortValue: (r) => r.kind },
            { key: "name", header: t("common.name"), primary: true, cell: (r) => r.name, sortValue: (r) => r.name },
            { key: "env", header: t("common.environment"), cell: (r) => r.environmentRef ?? "-" },
            { key: "rev", header: t("config.desired"), align: "right", cell: (r) => r.desiredRevision },
            { key: "applied", header: t("config.applied"), align: "right", cell: (r) => r.appliedRevision ?? "-" },
            { key: "status", header: t("common.status"), cell: (r) => <StatusTag status={r.status} /> },
            { key: "updated", header: t("common.updated"), cell: (r) => relativeTime(r.updatedAt, locale), sortValue: (r) => r.updatedAt },
          ]}
          pageSize={30}
        />
      </Panel>
    </div>
  );
}
