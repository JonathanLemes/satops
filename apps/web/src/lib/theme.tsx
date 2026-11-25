import { createContext, useContext, useEffect, useState, type ReactNode } from "react";

type Theme = "light" | "dark" | "system";
const KEY = "satops.theme";
const ThemeContext = createContext({ resolvedTheme: "light" as "light" | "dark", setTheme: (_t: Theme) => {} });

function stored(): Theme {
  try {
    const v = localStorage.getItem(KEY);
    if (v === "light" || v === "dark") return v;
  } catch {
    return "system";
  }
  return "system";
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(stored);
  const [system, setSystem] = useState<"light" | "dark">(() =>
    typeof matchMedia !== "undefined" && matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light",
  );
  const resolvedTheme = theme === "system" ? system : theme;

  useEffect(() => {
    if (typeof matchMedia === "undefined") return;
    const media = matchMedia("(prefers-color-scheme: dark)");
    const change = () => setSystem(media.matches ? "dark" : "light");
    media.addEventListener("change", change);
    return () => media.removeEventListener("change", change);
  }, []);

  useEffect(() => {
    document.documentElement.classList.toggle("dark", resolvedTheme === "dark");
    document.documentElement.style.colorScheme = resolvedTheme;
  }, [resolvedTheme]);

  const setTheme = (t: Theme) => {
    setThemeState(t);
    try {
      localStorage.setItem(KEY, t);
    } catch {
      return;
    }
  };

  return <ThemeContext.Provider value={{ resolvedTheme, setTheme }}>{children}</ThemeContext.Provider>;
}

export const useTheme = () => useContext(ThemeContext);
