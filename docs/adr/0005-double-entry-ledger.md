# ADR 0005: Double-entry ledger enforced by the database

Status: accepted (2026-11-25)

## Context

Balances must always equal history and restricted accounts must never go negative, including under concurrency and crashes.

## Problem

Where to enforce ledger invariants.

## Decision

Postings are rows; deferrable constraint triggers verify that every journal has at least two postings and balances per asset; an insert trigger maintains balance projections and is the only writer; `CHECK` constraints forbid negative restricted balances and inconsistent totals; update and delete triggers make journals and postings immutable. Corrections are compensating journals.

## Alternatives considered

Validation only in Ecto changesets or memory locks (rejected: bypassable and not safe across replicas). Computing balances on read (rejected: expensive and hides drift). A plain CHECK for sums (rejected: CHECK cannot see other rows).

## Trade-offs

Logic lives partly in SQL; tests must run against a real database.

## Consequences

Invariants hold even if application code is wrong; `verify_invariants/1` recomputes balances from history to detect drift.

## Revisit when

Multi-asset conversion or very high posting rates where per-row triggers become a measured bottleneck.
