# ADR 0009: Kubernetes sandbox isolation

Status: accepted (2026-11-25)

## Context

Experiments delete pods, scale workloads and isolate networks.

## Problem

How to allow destructive experiments without endangering anything else.

## Decision

Experiment workloads live in `sandbox-*` namespaces created by the installer. The worker service account gets a namespaced Role there only; actions also check an allowlist. Sandbox namespaces have quotas, limit ranges and default-deny NetworkPolicies. The SatOps database is in the platform namespace and is never a target. Kubernetes actions exist only when the Kubernetes runtime is configured; Compose refuses them instead of simulating.

## Alternatives considered

cluster-admin for the worker (rejected). Mounting the Docker socket for Compose experiments (rejected: host takeover).

## Trade-offs

Some scenarios (database outage) are not available on Compose.

## Consequences

Blast radius is limited to the sandbox namespace.

## Revisit when

Multi-cluster experiments or an operator that provisions namespaces on demand.
