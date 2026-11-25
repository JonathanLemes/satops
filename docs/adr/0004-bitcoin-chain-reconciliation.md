# ADR 0004: Bitcoin chain reconciliation

Status: accepted (2026-11-25)

## Context

ZeroMQ notifications are fast but lossy. Nodes can disagree. Reorganizations change history.

## Problem

How to keep a correct local view of the chain.

## Decision

ZeroMQ only triggers work. A per-environment `SyncChain` job compares the stored best chain with a reference node chosen by most accumulated work among reachable regtest nodes, finds the common ancestor through `getblockheader`, and disconnects and connects blocks in one transaction. Sequence gaps and a periodic job force RPC backfill. Mempool is reconciled after the chain catches up.

## Alternatives considered

Treating ZeroMQ as a queue (rejected: it drops messages). Longest chain by height (rejected: validity follows work). Majority vote between nodes (rejected: not Bitcoin consensus).

## Trade-offs

Extra RPC calls per sync versus correctness after any gap or restart.

## Consequences

Restarts and lost notifications recover confirmed state. Transient mempool events missed during a disconnection may not be reconstructable; this is documented.

## Revisit when

Ingesting from many nodes or mainnet scale (out of scope for a regtest sandbox).
