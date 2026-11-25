import { graphql } from "@/gql";

export const WIDGET_OVERVIEW = graphql(`
  query Overview($environmentId: ID!) {
    overview(environmentId: $environmentId) {
      confirmedSats
      pendingSats
      utxoCount
      tipHeight
      tipHash
      tipTime
      mempoolSize
      openDiscrepancies
      firingAlerts
      ingestionLagBlocks
      ingestionLatencyMs
      lastReconciliation {
        id
        status
        completeness
        summary
        finishedAt
      }
      activeExperiments {
        id
        scenarioName
        status
        startedAt
      }
      recentExperiments {
        id
        scenarioName
        status
        finishedAt
        statusReason
      }
    }
  }
`);

export const WIDGET_NODES = graphql(`
  query WidgetNodes($environmentId: ID!) {
    nodes(environmentId: $environmentId) {
      isReference
      integration {
        id
        name
        status
      }
      latest {
        reachable
        height
        rpcLatencyMs
        peers
        observedAt
      }
      history(limit: 40) {
        observedAt
        rpcLatencyMs
        height
        reachable
      }
    }
  }
`);

export const WIDGET_TRANSACTIONS = graphql(`
  query WidgetTransactions($environmentId: ID!) {
    transactions(environmentId: $environmentId, first: 8) {
      nodes {
        id
        txid
        status
        confirmations
        totalOutSats
        firstSeenAt
      }
    }
  }
`);

export const WIDGET_VOLUME = graphql(`
  query WidgetVolume($environmentId: ID!) {
    transactionVolume(environmentId: $environmentId, hours: 24) {
      bucket
      count
      valueSats
    }
  }
`);

export const WIDGET_RECONCILIATION = graphql(`
  query WidgetReconciliation($environmentId: ID!) {
    reconciliationRuns(environmentId: $environmentId, limit: 20) {
      id
      status
      completeness
      summary
      insertedAt
      finishedAt
    }
  }
`);

export const WIDGET_JOBS = graphql(`
  query WidgetJobs {
    jobStats {
      queue
      state
      count
    }
  }
`);

export const WIDGET_REORGS = graphql(`
  query WidgetReorgs($environmentId: ID!) {
    chainOverview(environmentId: $environmentId) {
      reorganizations {
        id
        observedAt
        payload
      }
    }
  }
`);
