import { useApolloClient } from "@apollo/client/react";
import { Socket, type Channel } from "phoenix";
import { createContext, useContext, useEffect, useRef, useState, type ReactNode } from "react";

type Listener = (topic: string, payload: Record<string, unknown>) => void;

const TOPIC_QUERIES: Record<string, string[]> = {
  "block.connected": ["Overview", "ChainOverview", "Blocks", "Transactions", "Nodes", "WidgetNodes", "WidgetTransactions"],
  "block.disconnected": ["ChainOverview", "Blocks", "Transactions"],
  "chain.reorganized": ["ChainOverview", "Blocks", "Transactions", "Overview", "WidgetReorgs"],
  "transaction.observed": ["Transactions", "Overview", "Portfolio", "WidgetTransactions"],
  "transaction.confirmed": ["Transactions", "Overview", "Portfolio", "Wallets", "WidgetTransactions"],
  "transaction.unconfirmed": ["Transactions", "Overview", "Portfolio", "Wallets"],
  "node.status": ["Nodes", "WidgetNodes"],
  "node.disconnected": ["Nodes", "WidgetNodes", "Integrations"],
  "node.reconnected": ["Nodes", "WidgetNodes", "Integrations"],
  "reconciliation.progress": ["ReconciliationRuns", "ReconciliationRun", "Overview", "Discrepancies", "WidgetReconciliation"],
  "reconciliation.discrepancy_detected": ["Discrepancies", "Overview"],
  "experiment.progress": ["ExperimentRuns", "ExperimentRun", "Overview", "WidgetExperiments"],
  "experiment.step_completed": ["ExperimentRun"],
  "alert.fired": ["Alerts", "TopbarAlerts"],
  "ledger.journal_posted": ["Journals", "LedgerAccounts", "Overview", "CustomerBalances"],
};

interface RealtimeValue {
  connected: boolean;
  subscribe: (listener: Listener) => () => void;
}

const RealtimeContext = createContext<RealtimeValue>({ connected: false, subscribe: () => () => {} });

export function RealtimeProvider({ environmentId, children }: { environmentId: string | null; children: ReactNode }) {
  const client = useApolloClient();
  const [connected, setConnected] = useState(false);
  const listeners = useRef(new Set<Listener>());
  const pending = useRef(new Set<string>());
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (!environmentId) return;
    const socket = new Socket("/socket", { reconnectAfterMs: (tries: number) => Math.min(1000 * 2 ** tries, 30_000) });
    let channel: Channel | null = null;
    let wasDisconnected = false;

    const flush = () => {
      const include = [...pending.current];
      pending.current.clear();
      timer.current = null;
      if (include.length) client.refetchQueries({ include }).catch(() => undefined);
    };

    socket.onOpen(() => {
      setConnected(true);
      if (wasDisconnected) client.refetchQueries({ include: "active" }).catch(() => undefined);
    });
    socket.onClose(() => {
      setConnected(false);
      wasDisconnected = true;
    });
    socket.onError(() => setConnected(false));
    socket.connect();

    channel = socket.channel(`env:${environmentId}`, {});
    channel.on("event", ({ topic, payload }: { topic: string; payload: Record<string, unknown> }) => {
      for (const name of TOPIC_QUERIES[topic] ?? []) pending.current.add(name);
      if (!timer.current) timer.current = setTimeout(flush, 400);
      listeners.current.forEach((l) => l(topic, payload));
    });
    channel.join();

    return () => {
      channel?.leave();
      socket.disconnect();
      if (timer.current) clearTimeout(timer.current);
    };
  }, [environmentId, client]);

  const value = useRef<RealtimeValue>({
    connected: false,
    subscribe: (l) => {
      listeners.current.add(l);
      return () => listeners.current.delete(l);
    },
  });

  return <RealtimeContext.Provider value={{ ...value.current, connected }}>{children}</RealtimeContext.Provider>;
}

export const useRealtime = () => useContext(RealtimeContext);
