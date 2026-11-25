# Event processing

## Durable events

Domain events are rows in `events` written in the **same transaction** as the state change that produced
them (`Events.append!/1` refuses to run outside a transaction). Each event has:

`id` (event identity), `event_type`, `schema_version`, `environment_id`, `network_id`, `aggregate_type`,
`aggregate_id`, `aggregate_version`, `occurred_at`, `observed_at`, `correlation_id`, `causation_id`,
optional `dedupe_key` and `payload`.

Event identity, transaction identity and financial operation identity are different things:

- a transaction `tx:<txid>` can produce several `transaction.confirmed` events over time (a new confirmation
  after a reorganization is a new, legitimate event; its dedupe key includes the aggregate version);
- a financial operation `deposit:<txid>:<vout>` can produce several journals (`detected:g0`, `confirmed:g0`,
  `reversed:g0`, `detected:g1`, ...).

Event types: `block.connected`, `block.disconnected`, `chain.reorganized`, `transaction.observed`,
`transaction.confirmed`, `transaction.unconfirmed`, `transaction.replaced`, `transaction.conflicted`,
`node.disconnected`, `node.reconnected`, `node.synchronized`, `node.diverged`, `ledger.journal_posted`,
`ledger.deposit_credited`, `ledger.deposit_reversed`, `reconciliation.completed`, `reconciliation.incomplete`,
`reconciliation.discrepancy_detected`, `experiment.step_completed`, `experiment.finished`,
`integration.unavailable`, `integration.recovered`, `integration.records_received`, `config.applied`.

## Ordering

`append!` takes a transaction-scoped advisory lock before inserting, so the `bigserial` sequence is assigned
in commit order and a consumer reading `seq > checkpoint` never skips an event that commits later with a
smaller number. The trade-off is that event producers serialize for the short tail of their transaction;
producers append events at the end of their work to keep that window small.

## Delivery

Instead of an outbox plus a broker, appending an event inserts a unique Oban `DispatchWorker` job per
interested consumer in the same transaction. The dispatcher:

1. locks the consumer row in `consumer_checkpoints` (`FOR UPDATE`), which also prevents two workers or two
   replicas from processing the same consumer concurrently;
2. reads the next event after the checkpoint;
3. inserts `(consumer, event_id)` into `processed_events` with `ON CONFLICT DO NOTHING`;
4. runs the handler **inside the same transaction**;
5. advances the checkpoint.

If the handler fails, everything rolls back and Oban retries with exponential backoff and jitter. A poison
event stops that consumer (other consumers continue) until it is fixed; this keeps per-consumer ordering.

Delivery is at least once. Effects are made effectively once by the combination of processed markers,
domain idempotency keys and database constraints. Exactly-once delivery is not claimed.

## Consumers

| Consumer | Interested in | Effect |
|---|---|---|
| `ledger.chain` | transaction events, `block.connected` | Evaluates deposits for monitored addresses and posts journals |
| `alerts` | alertable events and recoveries | Opens, deduplicates, cools down and resolves alert occurrences, schedules webhook deliveries |
| `realtime.broadcaster` | everything | Ephemeral Phoenix PubSub notification for the UI (never a source of truth) |

## Replay

`Events.replay(consumer, from_seq)` moves the checkpoint back and removes processed markers from that point.
Replays are safe because handlers are idempotent at the domain level: the ledger consumer recomputes the
decision from current state and posts with idempotency keys. Replay is available to engineers in the Jobs page
and is audited.

## Realtime

The UI joins `env:<environment_id>` over Phoenix Channels. Messages only say *what* changed; the client maps
topics to GraphQL operation names and refetches them (debounced). After a reconnect it refetches every active
query, because subscriptions never replace queries for current state.
