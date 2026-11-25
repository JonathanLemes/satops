import { zodResolver } from "@hookform/resolvers/zod";
import { ShieldAlert } from "lucide-react";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { Navigate, useLocation, useNavigate } from "react-router";
import { z } from "zod";
import { LOCALES, useI18n } from "@/i18n";
import { ApiError } from "@/lib/api";
import { useSession } from "@/lib/session";
import { Button } from "@/components/ui/button";
import { Field, Input } from "@/components/ui/input";
import { Logo } from "@/components/ui/brand";
import { Notice, Segmented } from "@/components/ui/misc";

const schema = z.object({ email: z.string().email(), password: z.string().min(1) });
type Values = z.infer<typeof schema>;

export function LoginPage() {
  const { t, locale, setLocale } = useI18n();
  const { me, login } = useSession();
  const navigate = useNavigate();
  const location = useLocation();
  const [error, setError] = useState<string | null>(null);
  const form = useForm<Values>({ resolver: zodResolver(schema), defaultValues: { email: "", password: "" } });

  if (me) return <Navigate to={(location.state as { from?: string } | null)?.from ?? "/"} replace />;

  const submit = form.handleSubmit(async (values) => {
    setError(null);
    try {
      await login(values.email, values.password);
      navigate((location.state as { from?: string } | null)?.from ?? "/", { replace: true });
    } catch (e) {
      setError(e instanceof ApiError && e.status === 429 ? t("login.rateLimited") : t("login.invalid"));
    }
  });

  return (
    <div className="flex min-h-dvh items-center justify-center bg-background px-4 py-10">
      <div className="flex w-full max-w-[420px] flex-col gap-6">
        <div className="flex items-center justify-between">
          <Logo height={30} />
          <Segmented
            label={t("topbar.language")}
            value={locale}
            onChange={setLocale}
            options={LOCALES.map((l) => ({ value: l.value, label: l.short }))}
          />
        </div>
        <form onSubmit={submit} className="flex flex-col gap-5 rounded-lg bg-surface p-6 sm:p-8" noValidate>
          <div className="flex flex-col gap-1">
            <h1 className="text-2xl font-semibold">{t("login.title")}</h1>
            <p className="text-[13px] text-text-secondary">{t("login.subtitle")}</p>
          </div>
          <Field label={t("login.email")} error={form.formState.errors.email ? t("validation.email") : undefined}>
            {(id, desc) => (
              <Input
                id={id}
                type="email"
                autoComplete="username"
                aria-describedby={desc}
                aria-invalid={!!form.formState.errors.email}
                {...form.register("email")}
              />
            )}
          </Field>
          <Field
            label={t("login.password")}
            error={form.formState.errors.password ? t("validation.required") : undefined}
          >
            {(id, desc) => (
              <Input
                id={id}
                type="password"
                autoComplete="current-password"
                aria-describedby={desc}
                aria-invalid={!!form.formState.errors.password}
                {...form.register("password")}
              />
            )}
          </Field>
          {error ? (
            <p role="alert" className="text-sm text-danger">
              {error}
            </p>
          ) : null}
          <Button type="submit" variant="primary" size="xl" loading={form.formState.isSubmitting}>
            {t("login.submit")}
          </Button>
        </form>
        <Notice tone="warning">
          <ShieldAlert size={16} className="mt-0.5 shrink-0" />
          <span>{t("login.sandboxNote")}</span>
        </Notice>
      </div>
    </div>
  );
}
