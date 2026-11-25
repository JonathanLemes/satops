# Runbook: failed or inconclusive experiment

1. Open the run in Engineering > Experiments. Read the outcome line: it names the failing step or assertion.
2. **Failed step:** open the step to see parameters, result, checkpoint and failure reason. Typical causes:
   unavailable node or application, missing capability in the runtime, insufficient regtest funds.
3. **Failed assertion:** compare expected and actual. A false assertion with a healthy infrastructure is a
   finding about the system under test; keep the report.
4. **Inconclusive:** an action with unknown outcome was interrupted (for example mining or a reorganization)
   or a source was unavailable during verification. SatOps does not repeat such actions automatically.
   Inspect the chain and the applications, then start a new run.
5. Check cleanup status. If cleanup failed, run the cleanup actions manually (for example disable fault modes
   with `integration.set_fault` or reconnect peers) before the next run.
6. Download the JSON report and attach it to the investigation.
