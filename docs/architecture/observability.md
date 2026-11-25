# Observability and SLOs

## Signals

- **Logs:** JSON in production (`SATOPS_LOG_FORMAT=json`) with `environment_id`, `integration_id`, `event_id`,
  `operation_id`, `experiment_id`, `correlation_id` and `causation_id` metadata where available. Payloads and
  credentials are not logged; audit changes and reports are redacted.
- **Metrics:** Prometheus text at `GET /metrics` (internal network only):
  `chain_ingestion_lag_blocks`, `chain_reorganizations_total`, `zmq_sequence_gaps_total`,
  `bitcoin_rpc_duration_seconds`, `integration_reconnects_total`, `ledger_posting_duration_seconds`,
  `ledger_invariant_violations_total`, `reconciliation_runs_total`, `reconciliation_discrepancies`,
  `job_queue_depth`, `job_failures_total`, `experiment_duration_seconds`, `experiment_assertions_failed_total`,
  `http_request_duration_seconds`. Labels are low cardinality (method, queue, status, kind); txids, users and
  run ids are never labels.
- **Traces:** OpenTelemetry for Phoenix, Bandit and Ecto; exported only when `OTEL_EXPORTER_OTLP_ENDPOINT` is set.
- **Dashboards:** Grafana provisioning in `deploy/docker/grafana` (backend health, PostgreSQL view, background
  jobs, Bitcoin ingestion, reconciliation, experiments). The SatOps UI shows the operational and financial view;
  Grafana is for deeper technical analysis.

## Initial SLIs and objectives

These are objectives to validate with measurements, not proven guarantees.

| SLI | Measurement | Initial objective |
|---|---|---|
| Ingestion delay | `chain_ingestion_lag_blocks` sampled every 15 s | 0 blocks for 99% of samples while a node is reachable |
| Processing latency | time from block connected to ledger credit (event timestamps) | p95 under 10 s |
| Integration availability | healthy health checks / all checks | 99% per week in the sandbox |
| Recovery time | node back to ingestion caught up | under 2 minutes |
| Reconciliation completeness | complete runs / all runs | 95% per day; incomplete runs never count as success |
| Ledger integrity | `ledger_invariant_violations_total` | always 0 |
