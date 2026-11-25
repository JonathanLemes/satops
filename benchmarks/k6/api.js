import http from "k6/http";
import { check, sleep } from "k6";

const BASE = __ENV.SATOPS_BENCH_URL || "http://127.0.0.1:8470";

export const options = {
  scenarios: {
    read_mix: { executor: "constant-vus", vus: Number(__ENV.VUS || 10), duration: __ENV.DURATION || "60s" },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
  },
};

export function setup() {
  const res = http.post(`${BASE}/api/auth/login`, JSON.stringify({ email: __ENV.SATOPS_BENCH_EMAIL, password: __ENV.SATOPS_BENCH_PASSWORD }), {
    headers: { "content-type": "application/json" },
  });
  check(res, { "logged in": (r) => r.status === 200 });
  const body = res.json();
  const cookie = res.cookies.satops_session[0].value;
  return { csrf: body.csrfToken, env: body.environments[0].id, cookie };
}

const QUERIES = [
  "query($e: ID!){ overview(environmentId: $e){ confirmedSats pendingSats tipHeight openDiscrepancies } }",
  "query($e: ID!){ transactions(environmentId: $e, first: 25){ nodes { txid status confirmations } } }",
  "query($e: ID!){ ledgerInvariants(environmentId: $e){ ok totalDebits totalCredits } }",
  "query($e: ID!){ nodes(environmentId: $e){ latest { height rpcLatencyMs } } }",
];

export default function (ctx) {
  const query = QUERIES[Math.floor(Math.random() * QUERIES.length)];
  const res = http.post(`${BASE}/graphql`, JSON.stringify({ query, variables: { e: ctx.env } }), {
    headers: { "content-type": "application/json", "x-csrf-token": ctx.csrf, cookie: `satops_session=${ctx.cookie}` },
    tags: { query: query.slice(17, 40) },
  });
  check(res, { "200": (r) => r.status === 200, "no errors": (r) => !r.json("errors") });
  sleep(0.2);
}
