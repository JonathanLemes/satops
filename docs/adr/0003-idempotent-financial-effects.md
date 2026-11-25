# ADR 0003: Idempotent financial effects

Status: accepted (2026-11-25)

## Context

Events, webhooks and jobs are delivered at least once. Workers crash before and after commits.

## Problem

How to guarantee that a financial operation is applied once.

## Decision

Every journal has an idempotency record `(environment, scope, operation_id:entry_kind)` with a fingerprint of its parameters, written in the same transaction as the journal, plus a unique index on `(environment, operation_id, entry_kind)`. Same key and parameters replay the original result; different parameters return an explicit conflict. Consumers mark processed events in the handler's transaction.

## Alternatives considered

Relying on Oban job uniqueness (rejected: it only coalesces scheduling and is not a financial guarantee). Exactly-once delivery (rejected: not achievable in a distributed system).

## Trade-offs

Each operation needs a stable business key; callers must choose keys carefully.

## Consequences

Duplicate deliveries, retries after timeouts and concurrent duplicates produce one effect. Verified by property tests and by the `duplicate-deposit` and `worker-crash` scenarios.

## Revisit when

An operation cannot be keyed deterministically.
