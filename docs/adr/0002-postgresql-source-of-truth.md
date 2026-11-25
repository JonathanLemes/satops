# ADR 0002: PostgreSQL as the source of truth

Status: accepted (2026-11-25)

## Context

Financial state must be durable, transactional and auditable. Jobs, events and configuration also need durability.

## Problem

Which stores to use, and whether Kafka, RabbitMQ or Redis are needed.

## Decision

PostgreSQL is the only database. Oban provides durable jobs in the same database; events are a table; ETS is used only for disposable caches (rate limiter).

## Alternatives considered

Kafka for events (rejected: one more system to operate and no transactional write with business state without an outbox anyway). Redis for queues and locks (rejected: locks across replicas are already available as advisory locks and row locks). A separate event store database (rejected: no measured need).

## Trade-offs

Fewer moving parts and atomic writes versus PostgreSQL becoming a single point of failure and a throughput ceiling.

## Consequences

Backups of one database cover everything. Throughput is bounded by PostgreSQL; benchmarks track it.

## Revisit when

Event volume or consumer fan-out exceeds what a single PostgreSQL can serve with acceptable latency, measured.
