# ADR 0007: OTP for coordination, Oban for durable work

Status: accepted (2026-11-25)

## Context

Some work is long-lived connections (nodes, ZeroMQ); other work must survive restarts (syncs, experiments, deliveries).

## Problem

Which execution model to use for each.

## Decision

GenServers under a DynamicSupervisor own node connections and only record observations and enqueue jobs. Durable work runs in Oban queues with explicit concurrency. Experiments are state machines persisted in PostgreSQL and advanced by an Oban worker that holds a database lease; there is no per-run coordinator process.

## Alternatives considered

A GenServer per experiment as the source of truth (rejected: lost on crash, not exclusive across replicas). Registry for exclusivity (rejected: node-local).

## Trade-offs

Polling and leases add latency compared to in-memory coordination.

## Consequences

A crashed node or worker loses no state; another replica resumes from the database.

## Revisit when

Sub-second step latency becomes a requirement.
