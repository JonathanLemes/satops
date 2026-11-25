import { Dialog as D } from "radix-ui";
import { PanelLeftClose, PanelLeftOpen, X } from "lucide-react";
import { useEffect } from "react";
import { NavLink, useLocation } from "react-router";
import { useI18n } from "@/i18n";
import { useSession } from "@/lib/session";
import { cn } from "@/lib/utils";
import { Logo, LogoMark } from "@/components/ui/brand";
import { NAV, SETTINGS_ITEM, type NavItem } from "./navigation";

export function Sidebar({ collapsed, onToggle }: { collapsed: boolean; onToggle: () => void }) {
  return (
    <aside className={cn("sidebar sticky top-0 hidden h-dvh shrink-0 flex-col overflow-y-auto bg-sidebar px-3 py-[22px] transition-[width] duration-200 lg:flex", collapsed ? "w-[76px]" : "w-56")}>
      <SidebarContent collapsed={collapsed} onToggle={onToggle} />
    </aside>
  );
}

export function MobileNav({ open, onOpenChange }: { open: boolean; onOpenChange: (v: boolean) => void }) {
  const { pathname } = useLocation();
  const { t } = useI18n();
  useEffect(() => {
    onOpenChange(false);
  }, [pathname, onOpenChange]);
  return (
    <D.Root open={open} onOpenChange={onOpenChange}>
      <D.Portal>
        <D.Overlay className="anim-overlay fixed inset-0 z-40 bg-overlay lg:hidden" />
        <D.Content className="sidebar anim-sheet-left fixed inset-y-0 left-0 z-50 flex w-[min(300px,86vw)] flex-col overflow-y-auto bg-sidebar px-3 py-[22px] shadow-pop outline-none lg:hidden">
          <D.Title className="sr-only">{t("nav.menu")}</D.Title>
          <D.Description className="sr-only">{t("nav.menu")}</D.Description>
          <SidebarContent collapsed={false} onClose={() => onOpenChange(false)} />
        </D.Content>
      </D.Portal>
    </D.Root>
  );
}

function SidebarContent({ collapsed, onToggle, onClose }: { collapsed: boolean; onToggle?: () => void; onClose?: () => void }) {
  const { t } = useI18n();
  const { can } = useSession();

  const item = (n: NavItem) => (
    <NavLink
      key={n.to}
      to={n.to}
      end={n.end}
      title={collapsed ? t(n.label) : undefined}
      className={({ isActive }) =>
        cn(
          "group flex h-9 shrink-0 items-center gap-[11px] rounded-md px-[11px] text-[13px] font-semibold transition-colors",
          isActive ? "bg-[linear-gradient(90deg,var(--brand-glow),transparent)] text-white" : "text-[var(--sidebar-text)] hover:text-white",
          collapsed && "justify-center px-0",
        )
      }
    >
      <n.icon size={16} />
      {!collapsed && <span className="flex-1 truncate">{t(n.label)}</span>}
    </NavLink>
  );

  return (
    <>
      <div className={cn("group/brand relative flex h-[26px] shrink-0 items-center px-[11px]", collapsed && "justify-center px-0")}>
        {collapsed ? (
          <button type="button" onClick={onToggle} aria-label={t("nav.expand")} className="flex size-8 items-center justify-center rounded-md">
            <LogoMark size={24} />
          </button>
        ) : (
          <Logo height={24} className="text-[#e6e6e6]" />
        )}
        {!collapsed ? (
          <button
            type="button"
            onClick={onClose ?? onToggle}
            aria-label={onClose ? t("common.close") : t("nav.collapse")}
            className="absolute right-0 top-0 flex size-8 items-center justify-center rounded-md bg-sidebar text-[var(--sidebar-muted)] opacity-0 transition-opacity hover:bg-[var(--sidebar-surface)] focus-visible:opacity-100 group-hover/brand:opacity-100"
          >
            {onClose ? <X size={16} /> : <PanelLeftClose size={16} />}
          </button>
        ) : null}
      </div>
      {NAV.map((group, gi) => {
        const items = group.items.filter((i) => can(i.permission));
        if (!items.length) return null;
        return (
          <div key={group.label} className={cn("flex flex-col", gi === 0 ? "mt-6" : "mt-5")}>
            {gi > 0 ? <div className="mb-4 h-px shrink-0 bg-[var(--sidebar-border)]" /> : null}
            {!collapsed ? <p className="mb-2 flex h-5 items-center px-[11px] text-[11px] text-[#a1a1aa]">{t(group.label)}</p> : null}
            <nav aria-label={t(group.label)} className="flex flex-col gap-1">
              {items.map(item)}
            </nav>
          </div>
        );
      })}
      <div className="min-h-6 flex-1" />
      {!collapsed ? (
        <div className="mb-4 rounded-lg bg-[var(--sidebar-surface)] p-[13px] text-[11px] leading-[15px] text-[#c4c4ca]">
          <span className="block text-xs font-medium text-[#ffc070]">Regtest</span>
          <span>{t("app.sandbox")}</span>
        </div>
      ) : null}
      <div className="mb-3 h-px shrink-0 bg-[var(--sidebar-border)]" />
      <nav aria-label={t("nav.settings")}>{item(SETTINGS_ITEM)}</nav>
      {collapsed ? (
        <button type="button" onClick={onToggle} aria-label={t("nav.expand")} className="mt-3 flex size-9 items-center justify-center self-center rounded-md text-[var(--sidebar-muted)] hover:bg-[var(--sidebar-surface)]">
          <PanelLeftOpen size={16} />
        </button>
      ) : null}
    </>
  );
}
