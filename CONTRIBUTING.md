# Contributing to SatOps

Thank you for helping. SatOps handles financial correctness, so changes are judged first on correctness,
then simplicity, security and resilience.

## Ground rules

- Regtest and synthetic data only. Never add code paths that talk to mainnet, accept private keys or seed
  phrases, or move real funds.
- Money is always an integer number of satoshis. Floating point is never used for amounts.
- Posted journals are immutable. Corrections are compensating journals.
- Every behavior change comes with tests. Financial invariants get property-based tests.
- Do not weaken checks or assertions to make a pipeline green.

## Local setup

Requirements: Docker (Compose v2), Node 24 and pnpm 11. Elixir and Erlang run in a container.

```bash
make setup
make dev        # PostgreSQL on 127.0.0.1:5435 and two regtest nodes
make dev-api    # Phoenix on :4000
make dev-web    # Vite on :5173
```

`deploy/scripts/mix <task>` runs any Mix task inside the toolbox container with the dev database and nodes.

## Tests

| Command | What runs |
|---|---|
| `make test-unit` | Pure functions, rules, engine, state machines, property tests |
| `make test-integration` | Tests that commit to PostgreSQL (concurrency, crash recovery, idempotency) |
| `make test-bitcoin` | Chain sync, reorganizations and ledger effects against Bitcoin Core regtest |
| `make test-web` | Frontend typecheck, lint, Vitest, demo fintech tests |
| `make test-e2e` | Playwright against a running stack |
| `tests/resilience/run-scenarios.sh` | Every bundled SatLab scenario against a running stack |

Concurrency tests use `SatOps.CommittedCase`, which disables the SQL sandbox so transactions run on
independent connections. Use it whenever a test is about locking or isolation; the sandbox would serialize
the work and hide races.

## Style

- `mix format` and `mix credo --strict` (thresholds in `apps/api/.credo.exs`).
- Prettier and ESLint for TypeScript. TypeScript runs in strict mode.
- No comments in code: names, small functions and tests carry the intent. Architectural reasoning belongs
  in `docs/` and ADRs.
- Keep contexts small. A context never reads another context's tables directly; call its public functions.
- After changing the GraphQL schema run `make codegen` and commit the generated files.
- UI strings go through `useI18n()` and must exist in both `en.ts` and `pt-BR.ts` (a test enforces parity).

## Commits and pull requests

Conventional commit prefixes (`feat`, `fix`, `docs`, `test`, `refactor`, `chore`). Describe the guarantee a
change affects and how it was verified. Architectural decisions get an ADR in `docs/adr`.
