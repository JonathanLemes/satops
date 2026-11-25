# Benchmarks

Benchmarks are separate from functional tests and are reproducible from this repository. Numbers below were
measured, not estimated; rerun them before quoting them for another setup.

## Methodology

- **HTTP/GraphQL read mix** (`k6/api.js`): constant virtual users, each running one of four read queries
  (overview, transactions page, ledger invariants, node status) followed by a 200 ms pause. Run with
  `make benchmark` (`VUS`, `DURATION`, `SATOPS_BENCH_URL`, `SATOPS_BENCH_EMAIL`, `SATOPS_BENCH_PASSWORD`).
  Results are exported to `benchmarks/results/` (ignored by git except this README).
- **Ingestion catch-up**: the `load-test` SatLab scenario sends a burst of regtest transactions, mines one
  block and measures how long SatWatch takes to reach the node tip. Its JSON report records the timings.

## Environment of the recorded run (2026-11-25)

| Item | Value |
|---|---|
| Hardware | Intel Core i9-10900K, 32 GB RAM, NVMe, shared home server with other services running |
| Deployment | Docker Compose stack of this repository, `SATOPS_ROLE=all`, one API container (limit 2 CPU / 1 GB) |
| Application version | commit `23ab91c` |
| Versions | see [docs/versions.md](../docs/versions.md) |
| Dataset | default sandbox after the bundled scenarios ran: about 600 regtest blocks, a few hundred non-coinbase transactions, tens of journals |

## Results

**GraphQL read mix, 10 VUs, 60 s**

| Metric | Value |
|---|---|
| Requests | 2,733 (45.4 req/s, limited by the 200 ms think time) |
| Errors | 0% (5,465 checks passed) |
| Latency p50 / p90 / p95 / max | 14.4 ms / 41.8 ms / 49.1 ms / 78.7 ms |
| Resource use during the run | API about 194 MiB RAM, PostgreSQL about 136 MiB, CPU low single digits |

**Ingestion catch-up (`load-test` scenario)**

| Step | Value |
|---|---|
| Burst of 100 `sendtoaddress` calls through RPC | 3.7 s |
| Mine one block containing them | 21 ms |
| SatWatch reaches the node tip (block + 100 transactions + events) | 0.94 s |

## Bottlenecks and limitations

- The read mix is light on purpose; it measures API overhead, not maximum throughput. Increase `VUS` and
  remove the pause to find saturation.
- Event appends are serialized by an advisory lock (see [event processing](../docs/architecture/event-processing.md));
  this is the first expected bottleneck for very high event rates.
- Ledger postings check balance per journal with deferrable triggers; cost grows with postings per journal,
  not with ledger size.
- Measurements on a shared home server are noisy; compare runs on the same machine only.
- Ledger query performance under large synthetic datasets, recovery time after failures and database growth
  are not benchmarked yet.
