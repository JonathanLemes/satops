#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
PROJECT=$(docker compose config --format json | python3 -c 'import sys,json;print(json.load(sys.stdin)["name"])')
if [ "$PROJECT" != "satops" ]; then
  echo "Refusing to reset: compose project is '$PROJECT', expected 'satops'." >&2
  exit 1
fi
if docker compose config | grep -qiE 'mainnet|chain=main'; then
  echo "Refusing to reset: configuration mentions mainnet." >&2
  exit 1
fi
echo "This deletes the SatOps sandbox volumes (PostgreSQL, regtest chains, Prometheus, Grafana) of project '$PROJECT'."
echo "Other containers and volumes on this host are not touched."
read -r -p "Type the project name to confirm: " answer
[ "$answer" = "$PROJECT" ] || { echo "Aborted."; exit 1; }
docker compose --profile observability down --volumes --remove-orphans
echo "Sandbox reset. Run 'make up' and 'make admin EMAIL=...' to start again."
