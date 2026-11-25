# Configuration specification

Resources are SatOps specifications (not Kubernetes CRDs) with this envelope:

```yaml
apiVersion: satops.io/v1alpha1
kind: <Kind>
metadata:
  name: lowercase-name      # [a-z0-9-], unique per kind
  labels: {}                # optional
  description: ""           # optional
spec: {}
```

The JSON Schemas in [`packages/config-schemas/schemas`](../../packages/config-schemas/schemas) are the
contract. The browser validates with Ajv for immediate feedback; the backend validates again with the same
files and is the authority. Unknown fields are errors (`additionalProperties: false`), never dropped silently.

| Kind | Purpose | Notable fields |
|---|---|---|
| Environment | Sandbox with its own regtest network | `network.type: regtest` (const), `ledger.confirmationPolicy.requiredConfirmations`, `reconciliation.interval`, `safety.allowMainnet: false` (const) |
| BitcoinNetwork | Declared topology and reference policy | `nodes[].integrationRef`, `referencePolicy: mostWork` |
| BitcoinIntegration | Bitcoin Core node | `rpc.host`, `rpc.port`, `rpc.secretRef`, `zmq.endpoint`, `monitoring.reconcileInterval`, `priority` |
| FinancialIntegration | External application, CSV, webhooks | `type`, `secretRef`, `connection.baseUrl`, `webhook.secretRef`, `mapping.fields` |
| ReconciliationPolicy | Sources and timing | `sources`, `requiredSources`, `settlementDelaySeconds`, `matching: deterministic` |
| Experiment | Scenario | `steps[] {id, phase, action, params, timeout, maxAttempts}`, `assertions[]`, `requiredCapabilities` |
| Dashboard | Layout of registered widgets | `workspace`, `layout.columns: 12`, `widgets[] {id, type, position}` |
| AlertPolicy | Alert rules | `events`, `severity`, `cooldown`, `destinations[] {type: internal or webhook}` |

Durations use `500ms`, `30s` or `5m`.

## YAML rules

Accepted: a single document of mappings, sequences and scalars. Rejected with a line number when possible:
duplicate keys, custom tags, anchors, aliases and merge keys, multiple documents, documents above 128 KB, more
than 24 levels of nesting or 5,000 nodes. Comments and formatting are normalized to canonical YAML (ordered
envelope keys) when saved; this is a documented MVP limitation.

## Workflow

`Edit -> Validate -> Plan -> Review -> Apply -> Observe`

- **Plan** returns the action (create, update, noop), a list of changes by JSON pointer, a human impact list
  and both canonical YAML documents for a side-by-side diff.
- **Apply** takes the expected revision; a different current revision returns a conflict instead of
  overwriting. Identical specs are a no-op (no new revision).
- Each change creates an immutable revision with author and message. **Re-apply** creates a new revision with
  an old spec; it never rolls back financial effects or external operations.
- A reconciliation loop (every minute) re-applies resources whose applied revision differs from the desired
  revision and refreshes the observed state (for example integration status).

Credentials never appear in specifications: `secretRef` names a secret stored encrypted and managed by
administrators.
