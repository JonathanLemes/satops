# ADR 0001: Modular monolith

Status: accepted (2026-11-25)

## Context

SatOps combines chain ingestion, a ledger, reconciliation, experiments and configuration. These modules share data constantly (a confirmed transaction changes ledger balances, which reconciliation compares).

## Problem

How to separate domains without paying the cost of distributed transactions between them.

## Decision

Build one Elixir/Phoenix application with Phoenix contexts as module boundaries. The same release runs as API, worker or both through `SATOPS_ROLE`. No umbrella project.

## Alternatives considered

Microservices per module (rejected: posting, idempotency record, projection and event could no longer commit atomically; network failures between our own services would dominate the failure model). Umbrella apps (rejected: no module needs an independent OTP lifecycle today).

## Trade-offs

Simple deployment and atomic local transactions versus discipline needed to keep context boundaries (no context reads another's tables).

## Consequences

Contexts expose small public APIs; cross-context reactions use durable events. API and workers scale separately inside one codebase.

## Revisit when

A context needs an independent release cadence, a different runtime, or its load profile justifies isolation measured in production.
