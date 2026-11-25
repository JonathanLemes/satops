import { useMutation, useQuery } from "@apollo/client/react";
import { Plus } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import { graphql } from "@/gql";
import { LOCALES, useI18n } from "@/i18n";
import { api } from "@/lib/api";
import { useSession } from "@/lib/session";
import { formatDateTime } from "@/lib/utils";
import { DataTable } from "@/components/data/data-table";
import { Button } from "@/components/ui/button";
import { Field, Input, Select } from "@/components/ui/input";
import { PageHeader, Panel, PanelHeader, StatusTag } from "@/components/ui/misc";
import { Sheet } from "@/components/ui/overlay";

const USERS = graphql(`
  query Users {
    users {
      id
      email
      name
      role
      disabledAt
      insertedAt
    }
  }
`);

const CREATE_USER = graphql(`
  mutation CreateUser($email: String!, $name: String!, $role: String!, $password: String!, $environmentId: ID) {
    createUser(email: $email, name: $name, role: $role, password: $password, environmentId: $environmentId) {
      id
    }
  }
`);

const UPDATE_USER = graphql(`
  mutation UpdateUser($id: ID!, $role: String, $disabled: Boolean) {
    updateUser(id: $id, role: $role, disabled: $disabled) {
      id
    }
  }
`);

const LOCALE = graphql(`
  mutation UpdateLocale($locale: String!) {
    updateLocale(locale: $locale) {
      locale
    }
  }
`);

const ROLES = ["administrator", "engineer", "auditor", "viewer"] as const;

export default function SettingsPage() {
  const { t, locale, setLocale } = useI18n();
  const { me, can, environment } = useSession();
  const users = useQuery(USERS, { skip: !can("user.manage") });
  const [createUser] = useMutation(CREATE_USER);
  const [updateUser] = useMutation(UPDATE_USER);
  const [updateLocale] = useMutation(LOCALE);
  const [pw, setPw] = useState({ current: "", next: "" });
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ email: "", name: "", role: "viewer", password: "" });

  return (
    <div className="flex flex-col gap-5">
      <PageHeader title={t("settings.title")} />
      <div className="grid gap-5 lg:grid-cols-2">
        <Panel className="gap-4 p-5">
          <h2 className="text-base font-semibold">{t("settings.account")}</h2>
          <p className="text-[13px] text-text-secondary">
            {me?.user.name} · {me?.user.email} · {t(`settings.roles.${(me?.user.role ?? "viewer") as "viewer"}`)}
          </p>
          <Field label={t("settings.language")}>
            {(id) => (
              <Select
                id={id}
                value={locale}
                onChange={(e) => {
                  const l = e.target.value as (typeof LOCALES)[number]["value"];
                  setLocale(l);
                  updateLocale({ variables: { locale: l } }).catch(() => undefined);
                }}
              >
                {LOCALES.map((l) => (
                  <option key={l.value} value={l.value}>
                    {l.label}
                  </option>
                ))}
              </Select>
            )}
          </Field>
        </Panel>
        <Panel className="gap-4 p-5">
          <h2 className="text-base font-semibold">{t("settings.changePassword")}</h2>
          <form
            className="flex flex-col gap-3"
            onSubmit={async (e) => {
              e.preventDefault();
              try {
                await api("POST", "/api/auth/password", { current: pw.current, new: pw.next });
                setPw({ current: "", next: "" });
                toast.success(t("settings.passwordChanged"));
              } catch (err) {
                toast.error(err instanceof Error ? err.message : t("common.error"));
              }
            }}
          >
            <Field label={t("settings.currentPassword")}>
              {(id) => (
                <Input
                  id={id}
                  type="password"
                  autoComplete="current-password"
                  value={pw.current}
                  onChange={(e) => setPw({ ...pw, current: e.target.value })}
                />
              )}
            </Field>
            <Field label={t("settings.newPassword")} hint={t("settings.passwordRule")}>
              {(id, d) => (
                <Input
                  id={id}
                  aria-describedby={d}
                  type="password"
                  autoComplete="new-password"
                  minLength={12}
                  value={pw.next}
                  onChange={(e) => setPw({ ...pw, next: e.target.value })}
                />
              )}
            </Field>
            <Button type="submit" variant="primary" className="self-start" disabled={pw.next.length < 12}>
              {t("settings.changePassword")}
            </Button>
          </form>
        </Panel>
      </div>
      {can("user.manage") ? (
        <Panel>
          <PanelHeader
            title={t("settings.users")}
            actions={
              <Button variant="primary" onClick={() => setOpen(true)}>
                <Plus /> {t("settings.newUser")}
              </Button>
            }
          />
          <DataTable
            rows={users.data?.users}
            loading={users.loading}
            rowKey={(u) => u.id}
            columns={[
              { key: "name", header: t("common.name"), primary: true, cell: (u) => u.name },
              { key: "email", header: "Email", cell: (u) => u.email },
              {
                key: "role",
                header: t("settings.role"),
                cell: (u) => (
                  <Select
                    aria-label={t("settings.role")}
                    value={u.role}
                    disabled={u.id === me?.user.id}
                    onChange={async (e) => {
                      await updateUser({ variables: { id: u.id, role: e.target.value } });
                      users.refetch();
                    }}
                    className="w-40"
                  >
                    {ROLES.map((r) => (
                      <option key={r} value={r}>
                        {t(`settings.roles.${r}`)}
                      </option>
                    ))}
                  </Select>
                ),
              },
              {
                key: "status",
                header: t("common.status"),
                cell: (u) => <StatusTag status={u.disabledAt ? "skipped" : "healthy"} />,
              },
              { key: "created", header: t("common.created"), cell: (u) => formatDateTime(u.insertedAt, locale) },
              {
                key: "toggle",
                header: "",
                align: "right",
                cell: (u) =>
                  u.id !== me?.user.id ? (
                    <Button
                      size="sm"
                      onClick={async () => {
                        await updateUser({ variables: { id: u.id, disabled: !u.disabledAt } });
                        users.refetch();
                      }}
                    >
                      {u.disabledAt ? t("settings.enable") : t("settings.disable")}
                    </Button>
                  ) : null,
              },
            ]}
          />
        </Panel>
      ) : null}
      <Sheet
        open={open}
        onOpenChange={setOpen}
        title={t("settings.newUser")}
        footer={
          <Button
            variant="primary"
            disabled={!form.email || !form.name || form.password.length < 12}
            onClick={async () => {
              try {
                await createUser({ variables: { ...form, environmentId: environment?.id } });
                toast.success(t("settings.created"));
                setOpen(false);
                setForm({ email: "", name: "", role: "viewer", password: "" });
                users.refetch();
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
          <Field label="Email">
            {(id) => (
              <Input
                id={id}
                type="email"
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
              />
            )}
          </Field>
          <Field label={t("common.name")}>
            {(id) => <Input id={id} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />}
          </Field>
          <Field label={t("settings.role")}>
            {(id) => (
              <Select id={id} value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })}>
                {ROLES.map((r) => (
                  <option key={r} value={r}>
                    {t(`settings.roles.${r}`)}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          <Field label={t("settings.password")} hint={t("settings.passwordRule")}>
            {(id, d) => (
              <Input
                id={id}
                aria-describedby={d}
                type="password"
                autoComplete="new-password"
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
              />
            )}
          </Field>
        </div>
      </Sheet>
    </div>
  );
}
