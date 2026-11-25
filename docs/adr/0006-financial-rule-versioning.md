# ADR 0006: Versioned pure financial rules

Status: accepted (2026-11-25)

## Context

Financial interpretation changes over time; history must remain explainable.

## Problem

How to evolve rules without reinterpreting past operations.

## Decision

Rules are pure modules registered by `(name, version)` that turn facts into a journal draft. Journals store the rule name and version. Reversals and compensations mirror stored postings instead of recomputing with a newer rule.

## Alternatives considered

A single mutable rule set (rejected: silent reinterpretation). Rules embedded in persistence code (rejected: untestable).

## Trade-offs

Old versions must stay in the code while operations that used them may be compensated.

## Consequences

Rules are unit and property tested in isolation; the registry exposes which version is current.

## Revisit when

Rules need configuration by users rather than code.
