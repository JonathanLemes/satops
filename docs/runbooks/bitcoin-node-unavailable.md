# Runbook: Bitcoin node unavailable

**Signals:** `node.disconnected` alert, node shown as Unavailable in Engineering > Bitcoin nodes, rising
`integration_reconnects_total`, `chain_ingestion_lag_blocks` > 0.

1. Open Engineering > Bitcoin nodes. Check the last error and the availability history of the node.
2. Check that another node is reachable and marked Reference. If so, ingestion continues; no action is urgent.
3. Check the container or pod: `docker compose ps bitcoin-0` / `kubectl -n sandbox-default get pod bitcoin-0`.
   Logs: `docker compose logs --tail 200 bitcoin-0`.
4. If bitcoind exited, Compose and Kubernetes restart it. Wallets are loaded on startup; if an application
   reports "wallet not loaded", restart that application or let it reload on demand.
5. Use **Test connection** in Integrations. When healthy, use **Sync now** in Bitcoin nodes and confirm that the
   local tip matches the node tip.
6. If all nodes were down, confirm that no reconciliation run declared success meanwhile (runs must be
   `incomplete` or later than recovery).

Never point a sandbox integration at a non-regtest node: SatOps refuses it and the integration stays unavailable.
