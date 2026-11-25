# Consistency model

| Data | Source of truth | Consistency |
|---|---|---|
| Chain facts | Bitcoin Core (reference node) | SatOps converges to the reference node; local views lag by at most one sync cycle. |
| Ledger | PostgreSQL | Strong within a transaction. Every journal, its postings, the balance projection, the idempotency record and its event commit together. |
| Deposits from chain | Ledger consumer | Eventually consistent with the chain (event dispatch latency) but always consistent with itself. |
| Reconciliation | Run snapshot | Each run is a snapshot with a reference tip and source watermarks; it does not claim more than it observed. |
| Experiments | PostgreSQL rows | Step and run state are durable; process memory is disposable. |
| Configuration | Desired revision | Observed state converges to the desired revision through the reconcile loop. |
| UI | GraphQL queries | Realtime notifications only trigger refetches. |

## Chain view and reorganizations

The local chain is a projection of the reference node. Height is never used as validity: the reference node
is the reachable regtest node with the most accumulated work (configured priority breaks ties), and the
common ancestor is found by asking that node whether each local best block is still in its main chain
(`getblockheader.confirmations >= 1`). Disconnected blocks keep their rows with `in_best_chain = false`.
Their transactions become `unconfirmed`; they are not assumed to return to the mempool. Later they may become
`pending`, `confirmed` again, `conflicted`, `replaced` or `unknown`.

When nodes disagree, every node's observation is stored separately and a `node.diverged` event is emitted;
no voting is involved.

## Deposits

`Deposits.decide(state, tx_status, confirmations, required, block_changed)` is a pure function:

| Operation state | Transaction | Decision |
|---|---|---|
| none, reversed, cancelled | confirmed and final | detect, confirm |
| none, reversed, cancelled | pending, confirmed below policy, unconfirmed | detect |
| detected | final | confirm |
| detected | conflicted, replaced, unknown | cancel |
| credited | confirmed in the same block | nothing |
| credited | confirmed in a different block | reverse, detect, confirm (if final) |
| credited | anything else | reverse |

Reversals and cancellations bump the operation generation so the next credit uses new journal keys. If the
customer already spent a credit that is reversed, the shortfall is booked to a receivable instead of letting
a restricted account go negative.

## Withdrawals and concurrency

Withdrawals move funds from `available` to `reserved` inside one transaction. Both are restricted accounts;
the database `CHECK` rejects an overdraft under the row lock, so the check and the change are atomic even with
many concurrent requests (verified by `LedgerConcurrencyTest` with 20 parallel connections).

## Idempotency

| Operation | Key | Guarantee |
|---|---|---|
| Journal posting | `(environment_id, "journal", operation_id:entry_kind)` + fingerprint | Same parameters replay the original journal; different parameters return `idempotency_conflict` |
| Event append | `(environment_id, dedupe_key)` | Duplicate producers do not duplicate events |
| Event consumption | `(consumer, event_id)` | Handler effects commit with the processed marker |
| Webhooks | `(integration_id, delivery_id)` + HMAC + timestamp tolerance | Redeliveries are acknowledged without effects |
| External records | `(integration_id, source_record_id)` | Upserts; duplicates with new delivery ids do not duplicate records |
| Configuration apply | resource advisory lock + spec hash + expected revision | Re-applying identical specs is a no-op; concurrent edits conflict |
| Experiment steps | run lease + checkpoint + idempotency class | See below |

Oban job uniqueness is used only to coalesce work (for example one pending chain sync per environment). It is
not relied on for financial idempotency.

## Experiment recovery

Actions declare an idempotency class:

| Class | Example | On interruption |
|---|---|---|
| natural | `bitcoin.create_wallet`, `satwatch.sync_now` | Re-run |
| keyed | `ledger.request_withdrawal` (run-scoped key) | Re-run; the key prevents duplicates |
| verifiable | `bitcoin.send_transaction`, `bitcoin.ensure_funds` | Query state: done, not done, or unknown |
| compensable | none bundled yet | Mark unknown and require intervention |
| unsafe | `bitcoin.mine_blocks`, `bitcoin.reorganize_chain` | Never repeated; the step becomes `unknown` and the run `inconclusive` |

Steps are claimed under a lease stored in `experiment_runs`; a second worker cannot run the same run until the
lease expires, and the recovery job re-enqueues stalled runs.
