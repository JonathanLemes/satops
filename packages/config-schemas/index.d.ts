export type ResourceKind =
  | "Environment"
  | "BitcoinNetwork"
  | "BitcoinIntegration"
  | "FinancialIntegration"
  | "ReconciliationPolicy"
  | "Experiment"
  | "Dashboard"
  | "AlertPolicy";
export declare const schemas: Record<ResourceKind, Record<string, unknown>>;
export declare const kinds: ResourceKind[];
export declare const apiVersion: "satops.io/v1alpha1";
