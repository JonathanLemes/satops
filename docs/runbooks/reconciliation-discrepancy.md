# Runbook: reconciliation discrepancy

**Signals:** `reconciliation.discrepancy_detected` alert, open discrepancies on the dashboard.

1. Open the discrepancy. Read the reason, the source and the evidence (chain fact and source records).
2. Check the reference chain height of the run. If the transaction is recent, wait for the confirmation policy
   and the settlement delay; the next complete run resolves it automatically if it matches.
3. Mark it **Investigating** and add notes as you go.
4. Use the financial timeline (Open financial timeline) to see how the operation evolved: observed, confirmed,
   reorganized, credited, reversed.
5. Act on the source of the problem:
   - native ledger: post a compensating entry (administrators only) with a reason;
   - external application: correct it there. SatOps never edits external records.
6. Request a new reconciliation. Resolve with a note, or **Ignore** with a mandatory justification when the
   difference is expected.

If the run is `incomplete`, fix the unavailable source first; an incomplete run never proves the absence of
discrepancies.
