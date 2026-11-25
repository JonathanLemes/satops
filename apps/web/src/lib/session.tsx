import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { api, ApiError, setCsrfToken } from "./api";

export interface SessionEnvironment {
  id: string;
  slug: string;
  name: string;
  role: string | null;
  permissions: string[];
}

export interface Me {
  user: { id: string; email: string; name: string; role: string; locale: string };
  csrfToken: string;
  socketToken: string;
  permissions: string[];
  environments: SessionEnvironment[];
}

interface SessionValue {
  me: Me | null;
  loading: boolean;
  environment: SessionEnvironment | null;
  setEnvironmentId: (id: string) => void;
  can: (permission: string) => boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  refresh: () => Promise<void>;
}

const SessionContext = createContext<SessionValue | null>(null);
const ENV_KEY = "satops.environment";

export function SessionProvider({ children }: { children: ReactNode }) {
  const [me, setMe] = useState<Me | null>(null);
  const [loading, setLoading] = useState(true);
  const [environmentId, setEnvironmentIdState] = useState<string | null>(() => {
    try {
      return localStorage.getItem(ENV_KEY);
    } catch {
      return null;
    }
  });

  const apply = (data: Me | null) => {
    setMe(data);
    setCsrfToken(data?.csrfToken ?? null);
  };

  const refresh = useCallback(async () => {
    try {
      apply(await api<Me>("GET", "/api/auth/me"));
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) apply(null);
      else throw error;
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh().catch(() => setLoading(false));
  }, [refresh]);

  const login = useCallback(async (email: string, password: string) => {
    apply(await api<Me>("POST", "/api/auth/login", { email, password }));
  }, []);

  const logout = useCallback(async () => {
    await api("POST", "/api/auth/logout").catch(() => null);
    apply(null);
  }, []);

  const setEnvironmentId = useCallback((id: string) => {
    setEnvironmentIdState(id);
    try {
      localStorage.setItem(ENV_KEY, id);
    } catch {
      return;
    }
  }, []);

  const environment = useMemo(() => {
    if (!me) return null;
    return me.environments.find((e) => e.id === environmentId) ?? me.environments[0] ?? null;
  }, [me, environmentId]);

  const can = useCallback(
    (permission: string) =>
      (environment ? environment.permissions.includes(permission) : false) ||
      (me?.permissions.includes(permission) ?? false),
    [environment, me],
  );

  const value = useMemo(
    () => ({ me, loading, environment, setEnvironmentId, can, login, logout, refresh }),
    [me, loading, environment, setEnvironmentId, can, login, logout, refresh],
  );

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export function useSession() {
  const ctx = useContext(SessionContext);
  if (!ctx) throw new Error("useSession must be used inside SessionProvider");
  return ctx;
}

export function useEnvironmentId(): string {
  const { environment } = useSession();
  if (!environment) throw new Error("no environment selected");
  return environment.id;
}
