# ADR 0008: Declarative configuration with one canonical document

Status: accepted (2026-11-25)

## Context

Users want forms and power users want YAML; both must describe the same thing.

## Problem

How to keep Form and YAML equivalent and safe.

## Decision

Each resource kind has a JSON Schema in `packages/config-schemas`, used by Ajv in the browser for instant feedback and by the backend as the authority. YAML is parsed with duplicate keys, unknown tags, anchors, oversized and deeply nested documents rejected. Apply follows validate, plan (diff and impact), apply with expected revision, and a reconciliation loop converges observed state. Revisions are immutable.

## Alternatives considered

Kubernetes CRDs (rejected for now: would require a cluster for the Compose runtime). Separate form and YAML models (rejected: drift).

## Trade-offs

Comments and formatting are normalized to canonical YAML.

## Consequences

Unknown fields are reported, never silently dropped. Re-applying identical specs is a no-op. Rolling back configuration never rolls back financial effects.

## Revisit when

Resources need cross-resource transactions or templating.
