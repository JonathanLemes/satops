#!/bin/bash
set -euo pipefail
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<SQL
CREATE ROLE satops LOGIN PASSWORD '${SATOPS_DB_PASSWORD}';
CREATE DATABASE satops OWNER satops;
CREATE ROLE demo_fintech LOGIN PASSWORD '${DEMO_FINTECH_DB_PASSWORD}';
CREATE DATABASE demo_fintech OWNER demo_fintech;
REVOKE ALL ON DATABASE satops FROM PUBLIC;
REVOKE ALL ON DATABASE demo_fintech FROM PUBLIC;
SQL
if [ "${SATOPS_CREATE_TEST_DB:-false}" = "true" ]; then
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres -c "ALTER ROLE satops CREATEDB;"
fi
