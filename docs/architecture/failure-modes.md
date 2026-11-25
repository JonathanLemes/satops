# Failure modes

| Failure | Detection | Behavior | Verified by |
|---|---|---|---|
| Bitcoin node down | RPC errors in NodeMonitor, `node.disconnected` event, alert | Backoff with jitter; reference selection moves to another reachable node; sync resumes when the node returns | `bitcoin-node-failure` scenario |
| ZeroMQ messages lost | Sequence gaps per topic, `zmq_sequence_gaps_total` | Gap triggers an RPC sync; periodic sync every minute regardless | `missed-zmq-events` scenario, regtest test |
| Duplicate ZeroMQ messages | Sequence repeats | Counted and ignored | Unit tests |
| Chain reorganization | Local best block no longer in reference chain | Disconnect, reconnect, unconfirm transactions, reverse and re-credit deposits | `blockchain-reorganization` scenario, regtest test |
| Nodes disagree | Different best hashes among reachable nodes | `node.diverged` event, per-node observations, most-work reference | `network-partition` scenario |
| Worker crash before commit | Process exit | Transaction rolled back, nothing persisted | `worker-crash` scenario, resilience test |
| Worker crash after commit | Process exit | Retry replays the idempotent posting | `worker-crash` scenario, resilience test |
| Duplicate or reordered events | Processed markers, state-based decisions | No extra effects | `duplicate-deposit`, `out-of-order-events` |
| Concurrent withdrawals | Row lock + CHECK | Overdrafts rejected with `insufficient_funds` | `concurrent-withdrawals`, resilience test |
| External source unavailable | Adapter error | Run marked `incomplete`, `source_unavailable` discrepancy, never success | Reconciliation DB test |
| Experiment interrupted | Expired lease | Recovery by idempotency class, unknown outcome makes the run inconclusive | Runner logic, `RecoverStalled` cron |
| Database outage | Repo errors | Requests fail, jobs retry with backoff after the database returns; no partial postings | `database-outage` scenario (Kubernetes runtime) |
| Webhook replay | Delivery id unique, timestamp tolerance | 200 duplicate, no effects | `webhook-retry` scenario, API test |
| Invalid configuration | JSON Schema and semantic checks | Rejected with paths and lines; content kept for correction | Configuration tests, e2e |

## Findings from running the scenarios

Running the bundled scenarios against the live sandbox surfaced real defects that unit tests had missed,
which is the reason SatLab exists:

1. Reconciliation runs failed while persisting results, and an assertion counting open discrepancies passed
   anyway. The fix made `reconciliation.run` fail when the run fails and made the assertion require a
   completed run newer than the experiment.
2. After `bitcoin-node-failure` stopped `bitcoind`, the demo fintech's wallet was not loaded again on restart,
   so every following deposit failed. Wallets are now created with `load_on_startup` and reloaded on demand.
3. A fresh regtest chain is still in initial block download, which excluded every node from reference
   selection. Nodes in IBD are now used when nothing better exists.
