import { graphql } from "@/gql";

export const RUNS = graphql(`
  query ReconciliationRuns($environmentId: ID!) {
    reconciliationRuns(environmentId: $environmentId, limit: 50) {
      id
      status
      completeness
      trigger
      policyName
      policyVersion
      summary
      referenceHeight
      startedAt
      finishedAt
      insertedAt
    }
  }
`);

export const DISCREPANCIES = graphql(`
  query Discrepancies($environmentId: ID!, $states: [String!]) {
    discrepancies(environmentId: $environmentId, states: $states, limit: 200) {
      id
      kind
      state
      severity
      source
      txid
      vout
      amountSats
      reason
      occurrences
      updatedAt
    }
  }
`);

export const RUN_RECONCILIATION = graphql(`
  mutation RunReconciliation($environmentId: ID!) {
    runReconciliation(environmentId: $environmentId) {
      id
      status
    }
  }
`);
