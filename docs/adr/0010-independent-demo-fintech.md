# ADR 0010: Independent demo fintech

Status: accepted (2026-11-25)

## Context

Reconciliation must prove it detects incorrect applications, not only that SatOps agrees with itself.

## Problem

How to provide a realistic counterpart.

## Decision

The demo fintech is a separate Node.js service with its own database, credentials, wallet and ledger code, integrated only through its HTTP API and signed webhooks. Fault modes (duplicate credit, missing credit, wrong amount, delayed settlement, ignored reorg, duplicate webhooks, wrong balance projection, outage, timeout after success, slow responses) are explicit, logged and disabled by default.

## Alternatives considered

Reusing ClearLedger rules inside the demo (rejected: shared bugs would be invisible).

## Trade-offs

Two implementations to maintain.

## Consequences

`faulty-fintech-detection` passes only when reconciliation reports the injected duplicate credit.

## Revisit when

Integrating a third-party open-source fintech instead.
