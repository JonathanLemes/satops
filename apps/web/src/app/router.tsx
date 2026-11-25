import { lazy, Suspense } from "react";
import { createBrowserRouter, Navigate } from "react-router";
import { AppShell, RequirePermission } from "@/layouts/app-shell";
import { LoginPage } from "@/features/auth/login-page";
import { LoadingState } from "@/components/ui/misc";

const DashboardPage = lazy(() => import("@/features/overview/dashboard-page"));
const WalletsPage = lazy(() => import("@/features/wallets/wallets-page"));
const TransactionsPage = lazy(() => import("@/features/transactions/transactions-page"));
const TransactionDetailPage = lazy(() => import("@/features/transactions/transaction-detail-page"));
const ReconciliationPage = lazy(() => import("@/features/reconciliation/reconciliation-page"));
const RunDetailPage = lazy(() => import("@/features/reconciliation/run-detail-page"));
const DiscrepancyPage = lazy(() => import("@/features/reconciliation/discrepancy-page"));
const AuditPage = lazy(() => import("@/features/audit/audit-page"));
const AlertsPage = lazy(() => import("@/features/alerts/alerts-page"));
const LearnPage = lazy(() => import("@/features/learn/learn-page"));
const EnvironmentsPage = lazy(() => import("@/features/environments/environments-page"));
const NodesPage = lazy(() => import("@/features/nodes/nodes-page"));
const BlockchainPage = lazy(() => import("@/features/blockchain/blockchain-page"));
const IntegrationsPage = lazy(() => import("@/features/integrations/integrations-page"));
const LedgerPage = lazy(() => import("@/features/ledger/ledger-page"));
const ExperimentsPage = lazy(() => import("@/features/experiments/experiments-page"));
const ExperimentRunPage = lazy(() => import("@/features/experiments/experiment-run-page"));
const ConfigurationPage = lazy(() => import("@/features/configuration/configuration-page"));
const ConfigEditorPage = lazy(() => import("@/features/configuration/config-editor-page"));
const JobsPage = lazy(() => import("@/features/jobs/jobs-page"));
const SettingsPage = lazy(() => import("@/features/settings/settings-page"));

const page = (el: React.ReactNode, permission?: string) => {
  const content = <Suspense fallback={<LoadingState rows={6} />}>{el}</Suspense>;
  return permission ? <RequirePermission permission={permission}>{content}</RequirePermission> : content;
};

const engineering = (el: React.ReactNode, permission: string) => {
  const content = page(el, permission);
  return <RequirePermission permission="workspace.engineering">{content}</RequirePermission>;
};

export const router = createBrowserRouter([
  { path: "/login", element: <LoginPage /> },
  {
    element: <AppShell />,
    children: [
      { index: true, element: page(<DashboardPage workspace="customer" />, "workspace.customer") },
      { path: "wallets", element: page(<WalletsPage />, "wallet.read") },
      { path: "transactions", element: page(<TransactionsPage />, "blockchain.read") },
      { path: "transactions/:txid", element: page(<TransactionDetailPage />, "blockchain.read") },
      { path: "reconciliation", element: page(<ReconciliationPage />, "reconciliation.read") },
      { path: "reconciliation/runs/:id", element: page(<RunDetailPage />, "reconciliation.read") },
      { path: "reconciliation/discrepancies/:id", element: page(<DiscrepancyPage />, "reconciliation.read") },
      { path: "audit", element: page(<AuditPage />, "reconciliation.read") },
      { path: "alerts", element: page(<AlertsPage />, "alert.read") },
      { path: "learn", element: page(<LearnPage />) },
      { path: "engineering", element: page(<DashboardPage workspace="engineering" />, "workspace.engineering") },
      { path: "engineering/environments", element: engineering(<EnvironmentsPage />, "workspace.engineering") },
      { path: "engineering/nodes", element: engineering(<NodesPage />, "blockchain.read") },
      { path: "engineering/blockchain", element: engineering(<BlockchainPage />, "blockchain.read") },
      { path: "engineering/integrations", element: engineering(<IntegrationsPage />, "integration.read") },
      { path: "engineering/ledger", element: engineering(<LedgerPage />, "ledger.read") },
      { path: "engineering/experiments", element: engineering(<ExperimentsPage />, "experiment.read") },
      { path: "engineering/experiments/runs/:id", element: engineering(<ExperimentRunPage />, "experiment.read") },
      { path: "engineering/configuration", element: engineering(<ConfigurationPage />, "config.read") },
      { path: "engineering/configuration/:kind/:name", element: engineering(<ConfigEditorPage />, "config.read") },
      { path: "engineering/configuration/new", element: engineering(<ConfigEditorPage />, "config.apply") },
      { path: "engineering/jobs", element: engineering(<JobsPage />, "jobs.read") },
      { path: "settings", element: page(<SettingsPage />) },
      { path: "*", element: <Navigate to="/" replace /> },
    ],
  },
]);
