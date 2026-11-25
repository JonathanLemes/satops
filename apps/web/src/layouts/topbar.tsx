import { useQuery } from "@apollo/client/react";
import { Bell, Languages, LogOut, Menu as MenuIcon, Moon, Sun, UserRound } from "lucide-react";
import { useNavigate } from "react-router";
import { graphql } from "@/gql";
import { LOCALES, useI18n } from "@/i18n";
import { useRealtime } from "@/lib/realtime";
import { useSession } from "@/lib/session";
import { useTheme } from "@/lib/theme";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/input";
import { Avatar, StatusTag } from "@/components/ui/misc";
import { LogoMark } from "@/components/ui/brand";
import { Menu, MenuContent, MenuItem, MenuLabel, MenuSeparator, MenuTrigger } from "@/components/ui/overlay";

const TOPBAR_ALERTS = graphql(`
  query TopbarAlerts($environmentId: ID!) {
    alerts(environmentId: $environmentId, state: "firing", limit: 8) {
      id
      title
      severity
      state
      lastSeenAt
    }
  }
`);

export function Topbar({ onMenu }: { onMenu: () => void }) {
  const { t, locale, setLocale } = useI18n();
  const { me, environment, setEnvironmentId, logout, can } = useSession();
  const { resolvedTheme, setTheme } = useTheme();
  const { connected } = useRealtime();
  const navigate = useNavigate();
  const alerts = useQuery(TOPBAR_ALERTS, {
    variables: { environmentId: environment?.id ?? "" },
    skip: !environment || !can("alert.read"),
    pollInterval: 60_000,
  });
  const firing = alerts.data?.alerts ?? [];

  return (
    <header className="sticky top-0 z-30 flex h-14 shrink-0 items-center gap-2 bg-surface px-4 sm:gap-3 sm:px-8">
      <Button variant="ghost" size="icon" className="lg:hidden" aria-label={t("topbar.openMenu")} onClick={onMenu}>
        <MenuIcon size={20} />
      </Button>
      <LogoMark size={26} className="hidden sm:block lg:hidden" />
      <label className="flex min-w-0 items-center gap-2 text-[13px] text-text-secondary">
        <span className="hidden md:inline">{t("topbar.environment")}</span>
        <Select
          aria-label={t("topbar.environment")}
          value={environment?.id ?? ""}
          onChange={(e) => setEnvironmentId(e.target.value)}
          className="w-[180px] sm:w-[220px]"
        >
          {me?.environments.map((e) => (
            <option key={e.id} value={e.id}>
              {e.name}
            </option>
          ))}
        </Select>
      </label>
      <span
        className={cn("hidden items-center gap-1.5 rounded-full px-2 py-0.5 text-[11px] sm:inline-flex", connected ? "tone tone-success" : "tone tone-warning")}
        role="status"
        aria-live="polite"
      >
        <span aria-hidden className={cn("size-1.5 rounded-full bg-current", connected && "animate-pulse")} />
        {connected ? t("topbar.live") : t("topbar.reconnecting")}
      </span>
      <div className="flex-1" />
      <Menu>
        <MenuTrigger asChild>
          <Button variant="ghost" size="icon" aria-label={`${t("topbar.alerts")} (${firing.length})`} className="relative">
            <Bell size={16} />
            {firing.length ? <span className="absolute right-1.5 top-1.5 size-2 rounded-full bg-danger" aria-hidden /> : null}
          </Button>
        </MenuTrigger>
        <MenuContent className="w-80">
          <MenuLabel>{t("topbar.alerts")}</MenuLabel>
          {firing.length === 0 ? <p className="px-2.5 py-2 text-xs text-text-muted">{t("topbar.noAlerts")}</p> : null}
          {firing.map((a) => (
            <MenuItem key={a.id} onSelect={() => navigate("/alerts")}>
              <StatusTag status={a.severity === "critical" ? "failed" : "pending"} />
              <span className="min-w-0 flex-1 truncate">{a.title}</span>
            </MenuItem>
          ))}
        </MenuContent>
      </Menu>
      <Menu>
        <MenuTrigger asChild>
          <Button variant="ghost" size="md" aria-label={t("topbar.language")} className="gap-1.5">
            <Languages size={16} />
            <span className="text-xs">{LOCALES.find((l) => l.value === locale)?.short}</span>
          </Button>
        </MenuTrigger>
        <MenuContent>
          {LOCALES.map((l) => (
            <MenuItem key={l.value} onSelect={() => setLocale(l.value)}>
              <span aria-hidden className={cn("size-1.5 rounded-full", l.value === locale ? "bg-primary" : "bg-transparent")} />
              {l.label}
            </MenuItem>
          ))}
        </MenuContent>
      </Menu>
      <span aria-hidden className="hidden h-6 w-px bg-border md:block" />
      {me ? (
        <Menu>
          <MenuTrigger asChild>
            <button type="button" className="flex h-9 shrink-0 items-center gap-2.5 rounded-md text-left hover:bg-surface-2" aria-label={t("topbar.account")}>
              <span className="hidden min-w-0 flex-col gap-0.5 text-right md:flex">
                <span className="truncate text-xs font-semibold leading-4 text-text">{me.user.name}</span>
                <span className="text-[10px] leading-[14px] text-text-secondary">{t(`settings.roles.${me.user.role as "viewer"}`)}</span>
              </span>
              <Avatar name={me.user.name} size={34} />
            </button>
          </MenuTrigger>
          <MenuContent>
            <MenuLabel>{me.user.email}</MenuLabel>
            <MenuItem onSelect={() => navigate("/settings")}>
              <UserRound /> {t("settings.account")}
            </MenuItem>
            <MenuItem onSelect={() => setTheme(resolvedTheme === "dark" ? "light" : "dark")}>
              {resolvedTheme === "dark" ? <Sun /> : <Moon />}
              {resolvedTheme === "dark" ? t("topbar.light") : t("topbar.dark")}
            </MenuItem>
            <MenuSeparator />
            <MenuItem danger onSelect={() => logout().then(() => navigate("/login"))}>
              <LogOut /> {t("topbar.signOut")}
            </MenuItem>
          </MenuContent>
        </Menu>
      ) : null}
    </header>
  );
}
