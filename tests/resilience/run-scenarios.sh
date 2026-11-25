#!/usr/bin/env bash
set -euo pipefail
BASE=${SATOPS_URL:-http://127.0.0.1:8470}
EMAIL=$1
PASSWORD=$2
SCENARIOS=${SCENARIOS:-duplicate-deposit blockchain-reorganization worker-crash bitcoin-node-failure missed-zmq-events out-of-order-events concurrent-withdrawals delayed-settlement network-partition webhook-retry application-restart load-test faulty-fintech-detection}
OUT=$(dirname "$0")/reports
mkdir -p "$OUT"
JAR=$(mktemp)
trap 'rm -f "$JAR"' EXIT

json() { python3 -c "import sys,json; d=json.load(sys.stdin); print($1)"; }

ME=$(curl -sf -c "$JAR" -H 'content-type: application/json' -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" "$BASE/api/auth/login")
CSRF=$(echo "$ME" | json 'd["csrfToken"]')
ENV=$(echo "$ME" | json 'd["environments"][0]["id"]')
gql() { curl -sf -b "$JAR" -H 'content-type: application/json' -H "x-csrf-token: $CSRF" -d "$1" "$BASE/graphql"; }

SCENARIO_IDS=$(gql '{"query":"{ scenarios { id name } }"}')
failed=0

for name in $SCENARIOS; do
  sid=$(echo "$SCENARIO_IDS" | json "[s['id'] for s in d['data']['scenarios'] if s['name']=='$name'][0]")
  run=$(gql "{\"query\":\"mutation(\$e: ID!, \$s: ID!){ startExperiment(environmentId: \$e, scenarioId: \$s){ id } }\",\"variables\":{\"e\":\"$ENV\",\"s\":\"$sid\"}}" | json 'd["data"]["startExperiment"]["id"]')
  status=""
  for _ in $(seq 1 180); do
    status=$(gql "{\"query\":\"query(\$id: ID!){ experimentRun(id: \$id){ status } }\",\"variables\":{\"id\":\"$run\"}}" | json 'd["data"]["experimentRun"]["status"]')
    case $status in passed|failed|inconclusive|aborted) break ;; esac
    sleep 5
  done
  curl -sf -b "$JAR" "$BASE/api/reports/experiments/$run" -o "$OUT/$name.json" || true
  echo "$name: $status"
  [ "$status" = "passed" ] || failed=$((failed + 1))
done

exit "$failed"
