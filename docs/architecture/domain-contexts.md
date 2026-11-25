# Domain contexts

| Context | Module | Public responsibilities | Owns tables |
|---|---|---|---|
| Blockchain | `SatOps.Blockchain`, `ChainSync`, `NodeMonitor` | Canonical chain, reorganizations, transaction state machine, node observations, reference node selection | `blocks`, `transactions`, `tx_outputs`, `tx_inputs`, `tx_status_changes`, `node_observations`, `chain_checkpoints`, `zmq_checkpoints` |
| WalletMonitoring | `SatOps.WalletMonitoring` | Watch-only wallets, descriptor derivation through Bitcoin Core, balances without double counting, history, internal transfers | `watched_wallets`, `watched_addresses` |
| Ledger | `SatOps.Ledger`, `Ledger.Rules`, `Ledger.Deposits` | Double-entry postings, versioned rules, idempotency, withdrawals, transfers, compensations, invariant verification | `ledger_*` |
| Reconciliation | `SatOps.Reconciliation`, `Reconciliation.Engine` | Source collection, deterministic matching, discrepancy lifecycle, exports | `reconciliation_*`, `discrepancies`, `discrepancy_notes`, `external_records`, `webhook_receipts` |
| Experiments | `SatOps.Experiments`, `Runner`, `Actions`, `Assertions` | Scenario versions, runs, steps, leases, recovery, reports | `scenarios`, `experiment_*` |
| Environments | `SatOps.Environments` | Sandbox lifecycle and regtest enforcement | `environments` |
| Integrations | `SatOps.Integrations` + adapters | Adapter registry, health checks, credentials through secret references, webhooks, CSV import, SSRF policy | `integrations`, `integration_errors`, `secrets` |
| Configuration | `SatOps.Configuration` | Parse, validate, plan, apply and reconcile declarative resources | `config_resources`, `config_revisions` |
| Dashboards | `SatOps.Dashboards` | Widget registry, shared and personal layouts | `dashboards` |
| Events | `SatOps.Events` | Durable append, ordered dispatch, per-consumer checkpoints and replay | `events`, `consumer_checkpoints`, `processed_events` |
| Alerts | `SatOps.Alerts` | Policies, occurrences with lifecycle, cooldown, signed webhook delivery | `alert_*` |
| Identity | `SatOps.Identity` | Users, sessions, roles, memberships, rate limiting | `users`, `user_sessions`, `memberships` |
| Audit | `SatOps.Audit` | Append-only record of administrative and financial actions | `audit_entries` |

## Collaboration rules

- Synchronous calls between contexts go through public functions (for example `Reconciliation` calls
  `Ledger.operations/2` and `Blockchain.tip/1`).
- Decoupled reactions go through durable events (for example Blockchain emits `transaction.confirmed`;
  Ledger and Alerts consume it). Not every call is an event.
- The reconciliation engine does not depend on the native ledger: the ledger is just one of its sources, and
  the engine can run with only external applications.
- Adapters implement behaviours (`Integrations.Adapter`, `Integrations.FinancialSource`) only where there are
  several real implementations.

## Roles and permissions

| Permission group | Viewer | Auditor | Engineer | Administrator |
|---|---|---|---|---|
| Customer workspace, balances, transactions, reconciliation read | yes | yes | yes | yes |
| Engineering workspace, ledger, audit log, experiments read, jobs | | yes | yes | yes |
| Manage integrations, run reconciliation, resolve discrepancies, run experiments, apply config, post ledger operations | | | yes | yes |
| Users, secrets, compensating entries | | | | yes |

Roles are global and narrowed per environment by memberships (the effective role is the lower of the two;
administrators see every environment).
