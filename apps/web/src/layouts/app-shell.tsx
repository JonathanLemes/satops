import { useCallback, useState } from "react";
import { Navigate, Outlet, useLocation } from "react-router";
import { RealtimeProvider } from "@/lib/realtime";
import { useSession } from "@/lib/session";
import { LoadingState } from "@/components/ui/misc";
import { MobileNav, Sidebar } from "./sidebar";
import { Topbar } from "./topbar";

export function AppShell() {
  const { me, loading, environment } = useSession();
  const location = useLocation();
  const [collapsed, setCollapsed] = useState(() => {
    try {
      return localStorage.getItem("satops.sidebar") === "collapsed";
    } catch {
      return false;
    }
  });
  const [mobile, setMobile] = useState(false);
  const onMobileChange = useCallback((v: boolean) => setMobile(v), []);

  if (loading) return <LoadingState rows={6} className="mx-auto mt-24 max-w-xl" />;
  if (!me) return <Navigate to="/login" replace state={{ from: location.pathname }} />;

  const toggle = () => {
    setCollapsed((c) => {
      try {
        localStorage.setItem("satops.sidebar", c ? "expanded" : "collapsed");
      } catch {
        return !c;
      }
      return !c;
    });
  };

  return (
    <RealtimeProvider environmentId={environment?.id ?? null}>
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-surface focus:px-3 focus:py-2"
      >
        Skip to content
      </a>
      <div className="flex min-h-dvh">
        <Sidebar collapsed={collapsed} onToggle={toggle} />
        <MobileNav open={mobile} onOpenChange={onMobileChange} />
        <div className="flex min-w-0 flex-1 flex-col">
          <Topbar onMenu={() => setMobile(true)} />
          <main
            id="main"
            className="anim-arrive flex min-w-0 flex-1 flex-col gap-6 px-4 py-6 sm:px-8"
            key={environment?.id}
          >
            {environment ? <Outlet /> : null}
          </main>
        </div>
      </div>
    </RealtimeProvider>
  );
}

export function RequirePermission({ permission, children }: { permission: string; children: React.ReactNode }) {
  const { can } = useSession();
  if (!can(permission)) return <Navigate to="/" replace />;
  return <>{children}</>;
}
