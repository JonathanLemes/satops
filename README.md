# SatOps

> An open-source, self-hosted platform for Bitcoin observability, financial reconciliation, and resilience testing.

<p align="center">
  <img src="docs/screenshots/customer-overview.png" alt="SatOps financial overview with balances, transaction volume, reconciliation rate and node health">
</p>

SatOps answers three questions about applications that handle Bitcoin:

- **Observe**: what happened on the chain and in my infrastructure?
- **Verify**: are the financial records correct?
- **Simulate**: does the system keep its guarantees when things go wrong?

It is **not** an exchange, a wallet, a trading platform or a financial institution. It runs only against
**Bitcoin Core in regtest mode** with **synthetic data**. It never connects to mainnet, never asks for seed
phrases or private keys, and never moves real money.

| Module | What it does |
|---|---|
| **SatWatch** | Monitors regtest nodes through JSON-RPC and ZeroMQ, ingests blocks and transactions into a canonical chain view, handles reorganizations and watches synthetic wallets (addresses and public descriptors). |
| **ClearLedger** | A double-entry reference ledger in integer satoshis with invariants enforced by PostgreSQL, plus a deterministic reconciliation engine that compares the chain, the reference ledger and external applications. |
| **SatLab** | A durable scenario runner that reorganizes the chain, stops nodes, replays events or turns on fault modes in a demo fintech, then evaluates typed assertions and produces reproducible reports. |
| **Platform core** | Declarative configuration (Form and YAML over the same JSON Schemas), environments, integrations, identity and roles, audit trail, alerts, durable events and configurable dashboards. |

## Screenshots

All screenshots come from a live regtest sandbox with synthetic data and are regenerated with
`make screenshots`.

| Engineering overview | Engineering overview (dark) |
|---|---|
| ![Engineering overview](docs/screenshots/engineering-overview.png) | ![Engineering overview in dark mode](docs/screenshots/engineering-overview-dark.png) |

**SatWatch**

| Bitcoin nodes | Blockchain reorganizations |
|---|---|
| ![Bitcoin nodes with topology, latency and availability](docs/screenshots/nodes.png) | ![Reorganizations with depth and common ancestor](docs/screenshots/blockchain-reorganizations.png) |
| **Transactions** | **Transaction detail** |
| ![Transactions list](docs/screenshots/transactions.png) | ![Transaction outputs, state history and financial operations](docs/screenshots/transaction-detail.png) |
| **Wallets** | **Integrations** |
| ![Watch-only wallets and consolidated holdings](docs/screenshots/wallets.png) | ![Integrations with health and connection tests](docs/screenshots/integrations.png) |

**ClearLedger**

| Discrepancies | Discrepancy detail |
|---|---|
| ![Open discrepancies](docs/screenshots/discrepancies.png) | ![Duplicate credit with evidence and suggested correction](docs/screenshots/discrepancy-detail.png) |
| **Reconciliation run** | **Financial timeline** |
| ![Reconciliation run with sources, watermarks and results](docs/screenshots/reconciliation-run.png) | ![Deposit lifecycle across a reorganization](docs/screenshots/financial-timeline.png) |
| **Reference ledger** | **Sign in** |
| ![Journals of the double-entry ledger](docs/screenshots/ledger-journals.png) | ![Sign-in page](docs/screenshots/login.png) |

**SatLab and declarative configuration**

| Experiments | Experiment run |
|---|---|
| ![Bundled resilience scenarios](docs/screenshots/experiments.png) | ![Blockchain reorganization scenario that passed](docs/screenshots/experiment-run.png) |
| **Configuration as a form** | **The same resource as YAML** |
| ![Bitcoin integration edited as a form generated from JSON Schema](docs/screenshots/configuration-form.png) | ![Bitcoin integration in the YAML editor](docs/screenshots/configuration-yaml.png) |
| **Plan before apply** | |
| ![Plan with impact and side by side diff](docs/screenshots/configuration-plan.png) | |

## Architecture at a glance

```mermaid
flowchart LR
  subgraph Sandbox["Regtest sandbox (isolated network)"]
    B0[(bitcoin-0)] <--> B1[(bitcoin-1)]
    DF[Demo Fintech<br/>own DB and ledger]
  end
  subgraph SatOps["SatOps modular monolith (Elixir/Phoenix)"]
    SW[SatWatch<br/>NodeMonitor + ChainSync]
    EV[(Durable events<br/>PostgreSQL)]
    LG[Ledger]
    RC[Reconciliation]
    LAB[SatLab runner<br/>Oban + leases]
    CFG[Configuration<br/>validate, plan, apply]
  end
  WEB[React app<br/>Customer and Engineering workspaces]
  B0 -- ZMQ + RPC --> SW
  B1 -- ZMQ + RPC --> SW
  SW --> EV --> LG
  DF -- REST + signed webhooks --> RC
  LG --> RC
  LAB -- whitelisted actions --> B0
  LAB --> DF
  WEB -- GraphQL + Phoenix Channels --> SatOps
```

One Elixir release serves both API and workers (`SATOPS_ROLE=all|api|worker`). PostgreSQL is the only
database and the source of truth; Oban provides durable jobs on the same database. See
[docs/architecture/overview.md](docs/architecture/overview.md).

## Quick start (Docker Compose)

Requirements: Docker with Compose v2, about 3 GB of RAM and 2 CPUs.

```bash
cp .env.example .env            # then replace every change-me value (see below)
make up                          # builds and starts PostgreSQL, two regtest nodes, the API, the demo fintech and the web app
make admin EMAIL=you@example.com # prints a one-time password for the first administrator
open http://127.0.0.1:8470
```

Generate secrets with `openssl rand -base64 48`. The default bind address is `127.0.0.1`; nothing is exposed
to other hosts unless you change `SATOPS_BIND_ADDRESS`. Optional Prometheus and Grafana:
`docker compose --profile observability up -d` (Grafana on `127.0.0.1:8471`).

On first boot SatOps applies the resources in [`examples/environments/bootstrap`](examples/environments/bootstrap):
the `default-sandbox` environment, both regtest nodes, the demo fintech integration, a reconciliation policy and
default alerts, plus the bundled scenarios in [`examples/scenarios`](examples/scenarios).

## What you can do

- Follow node health, chain tip, divergence between nodes, ZeroMQ gaps and reorganizations.
- Watch synthetic wallets and see confirmed and pending balances without double counting shared outputs.
- Inspect every transaction with its state history (confirmations are never treated as final).
- Reconcile the chain against the reference ledger and the demo fintech; investigate discrepancies with
  evidence, notes, manual links, suggested corrections and exports.
- Edit any resource as a form or as YAML, review a plan with a diff and impact, apply with optimistic
  concurrency and re-apply previous revisions.
- Run resilience scenarios and download JSON reports.
- Use the interface in **English** or **Brazilian Portuguese**.

## Resilience scenarios

All scenarios run against real regtest nodes and a real (deliberately faulty when asked) demo fintech.

| Scenario | Guarantee checked | Docker Compose runtime |
|---|---|---|
| duplicate-deposit | One deposit produces exactly the expected net credit, even after 100 redeliveries | supported |
| blockchain-reorganization | Credits follow confirmation changes and are reversed and re-credited explicitly | supported |
| worker-crash | No partial effect before commit, no duplicate effect on retry after commit | supported |
| bitcoin-node-failure | Ingestion recovers after the primary node is stopped | supported |
| missed-zmq-events | Confirmed state is rebuilt through RPC after notifications are lost | supported |
| out-of-order-events | Financial state is not corrupted by event reordering | supported |
| concurrent-withdrawals | Available balance is never spent twice | supported |
| delayed-settlement | Late settlement stays pending inside the policy window | supported |
| database-outage | Processing resumes after the application database returns | requires the Kubernetes runtime |
| network-partition | State converges to the heavier chain after the partition heals | supported |
| webhook-retry | Retried webhooks are accepted once | supported |
| application-restart | Supervised processes restart and state is read back from PostgreSQL | supported |
| load-test | Ingestion catch-up time is measured, not assumed | supported |
| faulty-fintech-detection | A fintech that credits twice is detected by reconciliation | supported |

Scenarios that need a capability the current runtime does not have are refused during validation. Actions are
never simulated when their runtime is unavailable.

## Development

```bash
make setup         # pnpm install, dev containers, mix deps, dev database
make dev           # PostgreSQL and two regtest nodes for development
make dev-api       # Phoenix on :4000
make dev-web       # Vite on :5173 (proxies /api, /graphql and /socket)
make test          # backend unit, property, integration and regtest tests plus frontend checks
make lint
make codegen       # export the GraphQL schema and regenerate TypeScript types
```

Elixir runs inside a container (`deploy/scripts/mix`), so only Docker and Node 24 with pnpm are needed on the
host. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Documentation

- Architecture: [overview](docs/architecture/overview.md), [domain contexts](docs/architecture/domain-contexts.md),
  [data model](docs/architecture/data-model.md), [event processing](docs/architecture/event-processing.md),
  [consistency model](docs/architecture/consistency-model.md), [supervision tree](docs/architecture/supervision-tree.md),
  [deployment](docs/architecture/deployment.md), [failure modes](docs/architecture/failure-modes.md),
  [configuration specification](docs/architecture/configuration-specification.md),
  [observability and SLOs](docs/architecture/observability.md)
- Decisions: [docs/adr](docs/adr)
- Operations: [runbooks](docs/runbooks), [threat model](docs/threat-model.md)
- Benchmarks: [benchmarks/README.md](benchmarks/README.md)

## License

[Apache License 2.0](LICENSE).
