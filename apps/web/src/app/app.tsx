import { ApolloProvider } from "@apollo/client/react";
import { useMemo } from "react";
import { RouterProvider } from "react-router";
import { Toaster } from "sonner";
import { I18nProvider } from "@/i18n";
import { createApolloClient } from "@/lib/apollo";
import { SessionProvider } from "@/lib/session";
import { ThemeProvider, useTheme } from "@/lib/theme";
import { router } from "./router";

function Toasts() {
  const { resolvedTheme } = useTheme();
  return <Toaster theme={resolvedTheme} position="bottom-right" toastOptions={{ className: "font-sans" }} />;
}

export function App() {
  const client = useMemo(() => createApolloClient(), []);
  return (
    <ThemeProvider>
      <I18nProvider>
        <ApolloProvider client={client}>
          <SessionProvider>
            <RouterProvider router={router} />
            <Toasts />
          </SessionProvider>
        </ApolloProvider>
      </I18nProvider>
    </ThemeProvider>
  );
}
