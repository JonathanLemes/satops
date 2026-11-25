import {
  Activity,
  BarChart3,
  BellRing,
  BookOpen,
  Boxes,
  FileCode2,
  FlaskConical,
  GitCompareArrows,
  History,
  LayoutDashboard,
  Layers,
  Link2,
  ListChecks,
  Server,
  Settings,
  Wallet,
  ArrowLeftRight,
  BookText,
} from "lucide-react";
import type { TranslationKey } from "@/i18n";

export interface NavItem {
  to: string;
  label: TranslationKey;
  icon: React.ComponentType<{ size?: number }>;
  permission: string;
  end?: boolean;
}

export interface NavGroup {
  label: TranslationKey;
  permission: string;
  items: NavItem[];
}

export const NAV: NavGroup[] = [
  {
    label: "nav.customer",
    permission: "workspace.customer",
    items: [
      { to: "/", label: "nav.overview", icon: LayoutDashboard, permission: "workspace.customer", end: true },
      { to: "/wallets", label: "nav.wallets", icon: Wallet, permission: "wallet.read" },
      { to: "/transactions", label: "nav.transactions", icon: ArrowLeftRight, permission: "blockchain.read" },
      { to: "/reconciliation", label: "nav.reconciliation", icon: GitCompareArrows, permission: "reconciliation.read" },
      { to: "/audit", label: "nav.auditTrail", icon: History, permission: "reconciliation.read" },
      { to: "/alerts", label: "nav.alerts", icon: BellRing, permission: "alert.read" },
      { to: "/learn", label: "nav.learn", icon: BookOpen, permission: "workspace.customer" },
    ],
  },
  {
    label: "nav.engineering",
    permission: "workspace.engineering",
    items: [
      {
        to: "/engineering",
        label: "nav.engineeringOverview",
        icon: BarChart3,
        permission: "workspace.engineering",
        end: true,
      },
      { to: "/engineering/environments", label: "nav.environments", icon: Layers, permission: "workspace.engineering" },
      { to: "/engineering/nodes", label: "nav.nodes", icon: Server, permission: "blockchain.read" },
      { to: "/engineering/blockchain", label: "nav.blockchain", icon: Boxes, permission: "blockchain.read" },
      { to: "/engineering/integrations", label: "nav.integrations", icon: Link2, permission: "integration.read" },
      { to: "/engineering/ledger", label: "nav.ledger", icon: BookText, permission: "ledger.read" },
      { to: "/engineering/experiments", label: "nav.experiments", icon: FlaskConical, permission: "experiment.read" },
      { to: "/engineering/configuration", label: "nav.configuration", icon: FileCode2, permission: "config.read" },
      { to: "/engineering/jobs", label: "nav.jobs", icon: ListChecks, permission: "jobs.read" },
    ],
  },
];

export const SETTINGS_ITEM: NavItem = {
  to: "/settings",
  label: "nav.settings",
  icon: Settings,
  permission: "dashboard.read",
};
export const ACTIVITY_ICON = Activity;
