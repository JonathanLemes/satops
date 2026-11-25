import Ajv, { type ErrorObject } from "ajv";
import addFormats from "ajv-formats";
import { schemas, type ResourceKind } from "@satops/config-schemas";

const ajv = new Ajv({ allErrors: true, strict: false });
addFormats(ajv);
const validators = Object.fromEntries(Object.entries(schemas).map(([k, s]) => [k, ajv.compile(s)])) as Record<ResourceKind, ReturnType<typeof ajv.compile>>;

export const KINDS = Object.keys(schemas) as ResourceKind[];

export function schemaFor(kind: string): JsonSchema | undefined {
  return (schemas as Record<string, JsonSchema>)[kind];
}

export interface JsonSchema {
  type?: string | string[];
  properties?: Record<string, JsonSchema>;
  required?: string[];
  items?: JsonSchema;
  enum?: unknown[];
  const?: unknown;
  default?: unknown;
  description?: string;
  pattern?: string;
  minimum?: number;
  maximum?: number;
  additionalProperties?: boolean | JsonSchema;
  title?: string;
}

export interface Issue {
  path: string;
  message: string;
}

export function validateLocal(doc: unknown): Issue[] {
  const kind = (doc as { kind?: string } | null)?.kind;
  if (!kind || !(kind in validators)) return [{ path: "/kind", message: `kind must be one of ${KINDS.join(", ")}` }];
  const validate = validators[kind as ResourceKind];
  if (validate(doc)) return [];
  return (validate.errors ?? []).map((e: ErrorObject) => ({
    path: e.instancePath || "/",
    message: e.keyword === "additionalProperties" ? `unknown field "${String(e.params.additionalProperty)}"` : (e.message ?? "invalid"),
  }));
}

export function knownPaths(schema: JsonSchema | undefined, value: unknown, prefix = ""): string[] {
  if (!schema || value === null || typeof value !== "object" || Array.isArray(value)) return [];
  const props = schema.properties ?? {};
  return Object.keys(value as Record<string, unknown>).flatMap((key) => {
    const child = props[key];
    if (!child) return schema.additionalProperties === false ? [`${prefix}/${key}`] : [];
    return knownPaths(child, (value as Record<string, unknown>)[key], `${prefix}/${key}`);
  });
}

export function template(kind: string, environment: string): Record<string, unknown> {
  const base = { apiVersion: "satops.io/v1alpha1", kind, metadata: { name: "" } };
  const specs: Record<string, unknown> = {
    Environment: { network: { type: "regtest", nodes: 2 }, ledger: { asset: "BTC", confirmationPolicy: { requiredConfirmations: 3 } }, safety: { allowMainnet: false, allowPublicPeers: false } },
    BitcoinNetwork: { environmentRef: environment, type: "regtest", referencePolicy: "mostWork", nodes: [] },
    BitcoinIntegration: { environmentRef: environment, network: "regtest", rpc: { host: "", port: 18443, secretRef: "bitcoin-rpc" }, zmq: { enabled: true, endpoint: "" }, monitoring: { reconcileInterval: "30s", timeout: "5s" } },
    FinancialIntegration: { environmentRef: environment, type: "generic_rest", connection: { baseUrl: "", timeout: "5s" }, mapping: { recordsPath: "/records" } },
    ReconciliationPolicy: { environmentRef: environment, sources: ["native-ledger"], requiredSources: ["native-ledger"], settlementDelaySeconds: 600, matching: "deterministic" },
    Experiment: { title: "", description: "", guarantee: "", steps: [{ id: "fund", phase: "prepare", action: "bitcoin.ensure_funds", params: { minimumSats: 100000000 } }], assertions: [{ type: "ledger.is_balanced" }] },
    Dashboard: { title: "", workspace: "engineering", layout: { columns: 12 }, widgets: [] },
    AlertPolicy: { environmentRef: environment, events: ["node.disconnected"], severity: "warning", cooldown: "5m", destinations: [{ type: "internal" }] },
  };
  return { ...base, spec: specs[kind] ?? {} };
}
