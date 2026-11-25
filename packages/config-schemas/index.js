import Environment from "./schemas/Environment.json" with { type: "json" };
import BitcoinNetwork from "./schemas/BitcoinNetwork.json" with { type: "json" };
import BitcoinIntegration from "./schemas/BitcoinIntegration.json" with { type: "json" };
import FinancialIntegration from "./schemas/FinancialIntegration.json" with { type: "json" };
import ReconciliationPolicy from "./schemas/ReconciliationPolicy.json" with { type: "json" };
import Experiment from "./schemas/Experiment.json" with { type: "json" };
import Dashboard from "./schemas/Dashboard.json" with { type: "json" };
import AlertPolicy from "./schemas/AlertPolicy.json" with { type: "json" };

export const schemas = { Environment, BitcoinNetwork, BitcoinIntegration, FinancialIntegration, ReconciliationPolicy, Experiment, Dashboard, AlertPolicy };
export const kinds = Object.keys(schemas);
export const apiVersion = "satops.io/v1alpha1";
