/* eslint-disable */
import type { TypedDocumentNode as DocumentNode } from '@graphql-typed-document-node/core';
export type Maybe<T> = T | null;
export type InputMaybe<T> = Maybe<T>;
export type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };
export type MakeOptional<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]?: Maybe<T[SubKey]> };
export type MakeMaybe<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]: Maybe<T[SubKey]> };
export type MakeEmpty<T extends { [key: string]: unknown }, K extends keyof T> = { [_ in K]?: never };
export type Incremental<T> = T | { [P in keyof T]?: P extends ' $fragmentName' | '__typename' ? T[P] : never };
/** All built-in and custom scalars, mapped to their actual values */
export type Scalars = {
  ID: { input: string; output: string; }
  String: { input: string; output: string; }
  Boolean: { input: boolean; output: boolean; }
  Int: { input: number; output: number; }
  Float: { input: number; output: number; }
  /**
   * The `DateTime` scalar type represents a date and time in the UTC
   * timezone. The DateTime appears in a JSON response as an ISO8601 formatted
   * string, including UTC timezone ("Z"). The parsed date and time string will
   * be converted to UTC if there is an offset.
   */
  DateTime: { input: string; output: string; }
  JSON: { input: any; output: any; }
  /** Integer amount of satoshis (safe up to 2^53) */
  Sats: { input: number; output: number; }
};

export type ActionDescriptor = {
  __typename?: 'ActionDescriptor';
  capabilities: Array<Scalars['String']['output']>;
  idempotency: Scalars['String']['output'];
  name: Scalars['String']['output'];
};

export type AlertDelivery = {
  __typename?: 'AlertDelivery';
  attempts: Scalars['Int']['output'];
  deliveredAt?: Maybe<Scalars['DateTime']['output']>;
  destination: Scalars['String']['output'];
  id: Scalars['ID']['output'];
  kind: Scalars['String']['output'];
  lastError?: Maybe<Scalars['String']['output']>;
  responseStatus?: Maybe<Scalars['Int']['output']>;
  status: Scalars['String']['output'];
  updatedAt?: Maybe<Scalars['DateTime']['output']>;
};

export type AlertOccurrence = {
  __typename?: 'AlertOccurrence';
  count: Scalars['Int']['output'];
  deliveries: Array<AlertDelivery>;
  details?: Maybe<Scalars['JSON']['output']>;
  fingerprint: Scalars['String']['output'];
  firstSeenAt: Scalars['DateTime']['output'];
  id: Scalars['ID']['output'];
  lastSeenAt: Scalars['DateTime']['output'];
  policyName?: Maybe<Scalars['String']['output']>;
  resolvedAt?: Maybe<Scalars['DateTime']['output']>;
  severity: Scalars['String']['output'];
  state: Scalars['String']['output'];
  title: Scalars['String']['output'];
};

export type AlertPolicy = {
  __typename?: 'AlertPolicy';
  cooldownSeconds: Scalars['Int']['output'];
  destinations?: Maybe<Scalars['JSON']['output']>;
  enabled: Scalars['Boolean']['output'];
  eventTypes: Array<Scalars['String']['output']>;
  id: Scalars['ID']['output'];
  name: Scalars['String']['output'];
  severity: Scalars['String']['output'];
};

export type AlertPolicyInput = {
  cooldownSeconds?: InputMaybe<Scalars['Int']['input']>;
  destinations?: InputMaybe<Scalars['JSON']['input']>;
  enabled?: InputMaybe<Scalars['Boolean']['input']>;
  eventTypes: Array<Scalars['String']['input']>;
  name: Scalars['String']['input'];
  severity?: InputMaybe<Scalars['String']['input']>;
};

export type AssertionResult = {
  __typename?: 'AssertionResult';
  actual?: Maybe<Scalars['JSON']['output']>;
  attempts: Scalars['Int']['output'];
  evaluatedAt: Scalars['DateTime']['output'];
  expected?: Maybe<Scalars['JSON']['output']>;
  id: Scalars['ID']['output'];
  message?: Maybe<Scalars['String']['output']>;
  outcome: Scalars['String']['output'];
  params?: Maybe<Scalars['JSON']['output']>;
  position: Scalars['Int']['output'];
  type: Scalars['String']['output'];
};

export type AuditEntry = {
  __typename?: 'AuditEntry';
  action: Scalars['String']['output'];
  actorEmail?: Maybe<Scalars['String']['output']>;
  changes?: Maybe<Scalars['JSON']['output']>;
  correlationId?: Maybe<Scalars['ID']['output']>;
  environmentId?: Maybe<Scalars['ID']['output']>;
  id: Scalars['ID']['output'];
  insertedAt: Scalars['DateTime']['output'];
  ip?: Maybe<Scalars['String']['output']>;
  resourceId?: Maybe<Scalars['String']['output']>;
  resourceType?: Maybe<Scalars['String']['output']>;
};

export type Balance = {
  __typename?: 'Balance';
  confirmedSats: Scalars['Sats']['output'];
  pendingSats: Scalars['Sats']['output'];
  utxoCount: Scalars['Int']['output'];
};

export type Block = {
  __typename?: 'Block';
  blockTime?: Maybe<Scalars['DateTime']['output']>;
  chainwork?: Maybe<Scalars['String']['output']>;
  connectedAt?: Maybe<Scalars['DateTime']['output']>;
  disconnectedAt?: Maybe<Scalars['DateTime']['output']>;
  hash: Scalars['String']['output'];
  height: Scalars['Int']['output'];
  inBestChain: Scalars['Boolean']['output'];
  prevHash?: Maybe<Scalars['String']['output']>;
  txCount: Scalars['Int']['output'];
};

export type ChainOverview = {
  __typename?: 'ChainOverview';
  checkpointHash?: Maybe<Scalars['String']['output']>;
  checkpointHeight?: Maybe<Scalars['Int']['output']>;
  checkpointUpdatedAt?: Maybe<Scalars['DateTime']['output']>;
  diverged: Scalars['Boolean']['output'];
  mempoolSize: Scalars['Int']['output'];
  referenceNode?: Maybe<Scalars['String']['output']>;
  reorganizations: Array<DomainEvent>;
  requiredConfirmations: Scalars['Int']['output'];
  staleBlocks: Array<Block>;
  tip?: Maybe<Block>;
  transactionCounts?: Maybe<Scalars['JSON']['output']>;
};

export type ConfigApplyResult = {
  __typename?: 'ConfigApplyResult';
  changed: Scalars['Boolean']['output'];
  resource: ConfigResource;
};

export type ConfigChange = {
  __typename?: 'ConfigChange';
  new?: Maybe<Scalars['JSON']['output']>;
  old?: Maybe<Scalars['JSON']['output']>;
  op: Scalars['String']['output'];
  path: Scalars['String']['output'];
};

export type ConfigIssue = {
  __typename?: 'ConfigIssue';
  column?: Maybe<Scalars['Int']['output']>;
  line?: Maybe<Scalars['Int']['output']>;
  message: Scalars['String']['output'];
  path?: Maybe<Scalars['String']['output']>;
};

export type ConfigPlan = {
  __typename?: 'ConfigPlan';
  action: Scalars['String']['output'];
  canonicalYaml: Scalars['String']['output'];
  changes: Array<ConfigChange>;
  currentRevision?: Maybe<Scalars['Int']['output']>;
  currentYaml?: Maybe<Scalars['String']['output']>;
  impact: Array<Scalars['String']['output']>;
  kind: Scalars['String']['output'];
  name: Scalars['String']['output'];
};

export type ConfigResource = {
  __typename?: 'ConfigResource';
  appliedRevision?: Maybe<Scalars['Int']['output']>;
  desiredRevision: Scalars['Int']['output'];
  document?: Maybe<Scalars['JSON']['output']>;
  environmentRef?: Maybe<Scalars['String']['output']>;
  id: Scalars['ID']['output'];
  kind: Scalars['String']['output'];
  name: Scalars['String']['output'];
  observed?: Maybe<Scalars['JSON']['output']>;
  revisions: Array<ConfigRevision>;
  status: Scalars['String']['output'];
  statusMessage?: Maybe<Scalars['String']['output']>;
  updatedAt: Scalars['DateTime']['output'];
  yaml?: Maybe<Scalars['String']['output']>;
};

export type ConfigRevision = {
  __typename?: 'ConfigRevision';
  authorEmail?: Maybe<Scalars['String']['output']>;
  insertedAt: Scalars['DateTime']['output'];
  message?: Maybe<Scalars['String']['output']>;
  revision: Scalars['Int']['output'];
  spec?: Maybe<Scalars['JSON']['output']>;
  yaml: Scalars['String']['output'];
};

export type ConfigValidation = {
  __typename?: 'ConfigValidation';
  canonicalYaml?: Maybe<Scalars['String']['output']>;
  document?: Maybe<Scalars['JSON']['output']>;
  errors: Array<ConfigIssue>;
  valid: Scalars['Boolean']['output'];
};

export type ConnectionTest = {
  __typename?: 'ConnectionTest';
  details?: Maybe<Scalars['JSON']['output']>;
  error?: Maybe<Scalars['String']['output']>;
  ok: Scalars['Boolean']['output'];
  status: Scalars['String']['output'];
};

export type ConsumerCheckpoint = {
  __typename?: 'ConsumerCheckpoint';
  consumer: Scalars['String']['output'];
  lag: Scalars['Int']['output'];
  lastSeq: Scalars['Int']['output'];
  updatedAt?: Maybe<Scalars['DateTime']['output']>;
};

export type CustomerBalance = {
  __typename?: 'CustomerBalance';
  accountRef: Scalars['String']['output'];
  availableSats: Scalars['Sats']['output'];
  pendingSats: Scalars['Sats']['output'];
  reservedSats: Scalars['Sats']['output'];
};

export type Dashboard = {
  __typename?: 'Dashboard';
  id: Scalars['ID']['output'];
  isDefault: Scalars['Boolean']['output'];
  lockVersion: Scalars['Int']['output'];
  name: Scalars['String']['output'];
  shared: Scalars['Boolean']['output'];
  spec: Scalars['JSON']['output'];
  title: Scalars['String']['output'];
  updatedAt?: Maybe<Scalars['DateTime']['output']>;
  workspace: Scalars['String']['output'];
};

export type Discrepancy = {
  __typename?: 'Discrepancy';
  amountSats?: Maybe<Scalars['Sats']['output']>;
  environmentId: Scalars['ID']['output'];
  evidence?: Maybe<Scalars['JSON']['output']>;
  firstRunId: Scalars['ID']['output'];
  id: Scalars['ID']['output'];
  insertedAt: Scalars['DateTime']['output'];
  kind: Scalars['String']['output'];
  lastRunId: Scalars['ID']['output'];
  lockVersion: Scalars['Int']['output'];
  matchKey: Scalars['String']['output'];
  notes: Array<DiscrepancyNote>;
  occurrences: Scalars['Int']['output'];
  reason: Scalars['String']['output'];
  resolution?: Maybe<Scalars['String']['output']>;
  resolvedAt?: Maybe<Scalars['DateTime']['output']>;
  severity: Scalars['String']['output'];
  source?: Maybe<Scalars['String']['output']>;
  state: Scalars['String']['output'];
  suggestion: Scalars['String']['output'];
  txid?: Maybe<Scalars['String']['output']>;
  updatedAt: Scalars['DateTime']['output'];
  vout?: Maybe<Scalars['Int']['output']>;
};

export type DiscrepancyNote = {
  __typename?: 'DiscrepancyNote';
  authorEmail?: Maybe<Scalars['String']['output']>;
  body: Scalars['String']['output'];
  data?: Maybe<Scalars['JSON']['output']>;
  id: Scalars['ID']['output'];
  insertedAt: Scalars['DateTime']['output'];
  kind: Scalars['String']['output'];
};

export type DomainEvent = {
  __typename?: 'DomainEvent';
  aggregateId: Scalars['String']['output'];
  aggregateType: Scalars['String']['output'];
  aggregateVersion?: Maybe<Scalars['Int']['output']>;
  causationId?: Maybe<Scalars['ID']['output']>;
  correlationId: Scalars['ID']['output'];
  environmentId: Scalars['ID']['output'];
  eventType: Scalars['String']['output'];
  id: Scalars['ID']['output'];
  networkId?: Maybe<Scalars['String']['output']>;
  observedAt: Scalars['DateTime']['output'];
  occurredAt: Scalars['DateTime']['output'];
  payload?: Maybe<Scalars['JSON']['output']>;
  schemaVersion: Scalars['Int']['output'];
  seq: Scalars['Int']['output'];
};

export type Environment = {
  __typename?: 'Environment';
  id: Scalars['ID']['output'];
  insertedAt?: Maybe<Scalars['DateTime']['output']>;
  kind: Scalars['String']['output'];
  name: Scalars['String']['output'];
  network: Scalars['String']['output'];
  requiredConfirmations: Scalars['Int']['output'];
  settings?: Maybe<Scalars['JSON']['output']>;
  slug: Scalars['String']['output'];
  status: Scalars['String']['output'];
};

export type ExperimentRun = {
  __typename?: 'ExperimentRun';
  assertions: Array<AssertionResult>;
  cleanupStatus: Scalars['String']['output'];
  environmentId: Scalars['ID']['output'];
  finishedAt?: Maybe<Scalars['DateTime']['output']>;
  id: Scalars['ID']['output'];
  insertedAt: Scalars['DateTime']['output'];
  report?: Maybe<Scalars['JSON']['output']>;
  scenarioId: Scalars['ID']['output'];
  scenarioName: Scalars['String']['output'];
  scenarioVersion: Scalars['Int']['output'];
  seed: Scalars['String']['output'];
  startedAt?: Maybe<Scalars['DateTime']['output']>;
  status: Scalars['String']['output'];
  statusReason?: Maybe<Scalars['String']['output']>;
  steps: Array<ExperimentStep>;
};

export type ExperimentStep = {
  __typename?: 'ExperimentStep';
  action: Scalars['String']['output'];
  attempts: Scalars['Int']['output'];
  checkpoint?: Maybe<Scalars['JSON']['output']>;
  evidence?: Maybe<Scalars['JSON']['output']>;
  failureReason?: Maybe<Scalars['String']['output']>;
  finishedAt?: Maybe<Scalars['DateTime']['output']>;
  id: Scalars['ID']['output'];
  maxAttempts: Scalars['Int']['output'];
  params?: Maybe<Scalars['JSON']['output']>;
  phase: Scalars['String']['output'];
  position: Scalars['Int']['output'];
  result?: Maybe<Scalars['JSON']['output']>;
  startedAt?: Maybe<Scalars['DateTime']['output']>;
  status: Scalars['String']['output'];
  stepKey: Scalars['String']['output'];
  timeoutMs: Scalars['Int']['output'];
};

export type FinancialRule = {
  __typename?: 'FinancialRule';
  current: Scalars['Boolean']['output'];
  name: Scalars['String']['output'];
  version: Scalars['Int']['output'];
};

export type Integration = {
  __typename?: 'Integration';
  capabilities: Array<Scalars['String']['output']>;
  checkpoint?: Maybe<Scalars['JSON']['output']>;
  config?: Maybe<Scalars['JSON']['output']>;
  enabled: Scalars['Boolean']['output'];
  enabledOperations?: Maybe<Array<Maybe<Scalars['String']['output']>>>;
  environmentId: Scalars['ID']['output'];
  errors: Array<IntegrationError>;
  health?: Maybe<Scalars['JSON']['output']>;
  id: Scalars['ID']['output'];
  kind: Scalars['String']['output'];
  lastError?: Maybe<Scalars['String']['output']>;
  lastSyncAt?: Maybe<Scalars['DateTime']['output']>;
  lockVersion: Scalars['Int']['output'];
  name: Scalars['String']['output'];
  retry?: Maybe<Scalars['JSON']['output']>;
  secretRef?: Maybe<Scalars['String']['output']>;
  status: Scalars['String']['output'];
  updatedAt?: Maybe<Scalars['DateTime']['output']>;
};

export type IntegrationError = {
  __typename?: 'IntegrationError';
  message: Scalars['String']['output'];
  occurredAt: Scalars['DateTime']['output'];
};

export type IntegrationInput = {
  config: Scalars['JSON']['input'];
  enabled?: InputMaybe<Scalars['Boolean']['input']>;
  kind: Scalars['String']['input'];
  lockVersion?: InputMaybe<Scalars['Int']['input']>;
  name: Scalars['String']['input'];
  secretRef?: InputMaybe<Scalars['String']['input']>;
};

export type InternalTransfer = {
  __typename?: 'InternalTransfer';
  fromWalletId: Scalars['ID']['output'];
  toWalletId: Scalars['ID']['output'];
  txid: Scalars['String']['output'];
  valueSats: Scalars['Sats']['output'];
};

export type Job = {
  __typename?: 'Job';
  attempt: Scalars['Int']['output'];
  attemptedAt?: Maybe<Scalars['DateTime']['output']>;
  completedAt?: Maybe<Scalars['DateTime']['output']>;
  errors?: Maybe<Scalars['JSON']['output']>;
  id: Scalars['ID']['output'];
  insertedAt?: Maybe<Scalars['DateTime']['output']>;
  maxAttempts: Scalars['Int']['output'];
  queue: Scalars['String']['output'];
  state: Scalars['String']['output'];
  worker: Scalars['String']['output'];
};

export type JobStat = {
  __typename?: 'JobStat';
  count: Scalars['Int']['output'];
  queue: Scalars['String']['output'];
  state: Scalars['String']['output'];
};

export type Journal = {
  __typename?: 'Journal';
  causationId?: Maybe<Scalars['ID']['output']>;
  correlationId?: Maybe<Scalars['ID']['output']>;
  description?: Maybe<Scalars['String']['output']>;
  entryKind: Scalars['String']['output'];
  id: Scalars['ID']['output'];
  metadata?: Maybe<Scalars['JSON']['output']>;
  operationId: Scalars['String']['output'];
  postedAt: Scalars['DateTime']['output'];
  postings: Array<Posting>;
  reversesJournalId?: Maybe<Scalars['ID']['output']>;
  ruleName: Scalars['String']['output'];
  ruleVersion: Scalars['Int']['output'];
};

export type LedgerAccount = {
  __typename?: 'LedgerAccount';
  asset: Scalars['String']['output'];
  balanceSats: Scalars['Sats']['output'];
  code: Scalars['String']['output'];
  creditTotal: Scalars['Sats']['output'];
  debitTotal: Scalars['Sats']['output'];
  id: Scalars['ID']['output'];
  name: Scalars['String']['output'];
  normalBalance: Scalars['String']['output'];
  ownerRef?: Maybe<Scalars['String']['output']>;
  restricted: Scalars['Boolean']['output'];
  type: Scalars['String']['output'];
};

export type LedgerInvariants = {
  __typename?: 'LedgerInvariants';
  balanced: Scalars['Boolean']['output'];
  duplicateCredits: Scalars['Int']['output'];
  negativeRestricted?: Maybe<Scalars['JSON']['output']>;
  ok: Scalars['Boolean']['output'];
  projectionDrift?: Maybe<Scalars['JSON']['output']>;
  totalCredits: Scalars['Sats']['output'];
  totalDebits: Scalars['Sats']['output'];
  unbalancedJournals: Array<Scalars['String']['output']>;
};

export type LedgerOperation = {
  __typename?: 'LedgerOperation';
  accountRef?: Maybe<Scalars['String']['output']>;
  amountSats: Scalars['Sats']['output'];
  asset: Scalars['String']['output'];
  blockHash?: Maybe<Scalars['String']['output']>;
  feeSats: Scalars['Sats']['output'];
  generation: Scalars['Int']['output'];
  id: Scalars['ID']['output'];
  kind: Scalars['String']['output'];
  operationId: Scalars['String']['output'];
  state: Scalars['String']['output'];
  txid?: Maybe<Scalars['String']['output']>;
  updatedAt?: Maybe<Scalars['DateTime']['output']>;
  vout?: Maybe<Scalars['Int']['output']>;
};

export type NodeObservation = {
  __typename?: 'NodeObservation';
  bestHash?: Maybe<Scalars['String']['output']>;
  chain?: Maybe<Scalars['String']['output']>;
  chainwork?: Maybe<Scalars['String']['output']>;
  error?: Maybe<Scalars['String']['output']>;
  height?: Maybe<Scalars['Int']['output']>;
  initialBlockDownload?: Maybe<Scalars['Boolean']['output']>;
  mempoolSize?: Maybe<Scalars['Int']['output']>;
  observedAt: Scalars['DateTime']['output'];
  peers?: Maybe<Scalars['Int']['output']>;
  reachable: Scalars['Boolean']['output'];
  rpcLatencyMs?: Maybe<Scalars['Int']['output']>;
};

export type NodeStatus = {
  __typename?: 'NodeStatus';
  downtime: Array<DomainEvent>;
  history: Array<NodeObservation>;
  integration: Integration;
  isReference: Scalars['Boolean']['output'];
  latest?: Maybe<NodeObservation>;
  zmq?: Maybe<ZmqCheckpoint>;
};


export type NodeStatusHistoryArgs = {
  limit?: InputMaybe<Scalars['Int']['input']>;
};

export type OperationTimeline = {
  __typename?: 'OperationTimeline';
  events: Array<DomainEvent>;
  journals: Array<Journal>;
  operation?: Maybe<LedgerOperation>;
};

export type Overview = {
  __typename?: 'Overview';
  activeExperiments: Array<ExperimentRun>;
  confirmedSats: Scalars['Sats']['output'];
  firingAlerts: Scalars['Int']['output'];
  ingestionLagBlocks?: Maybe<Scalars['Int']['output']>;
  ingestionLatencyMs?: Maybe<Scalars['Int']['output']>;
  lastReconciliation?: Maybe<ReconciliationRun>;
  mempoolSize: Scalars['Int']['output'];
  openDiscrepancies: Scalars['Int']['output'];
  pendingSats: Scalars['Sats']['output'];
  recentExperiments: Array<ExperimentRun>;
  tipHash?: Maybe<Scalars['String']['output']>;
  tipHeight?: Maybe<Scalars['Int']['output']>;
  tipTime?: Maybe<Scalars['DateTime']['output']>;
  utxoCount: Scalars['Int']['output'];
};

export type PageInfo = {
  __typename?: 'PageInfo';
  endCursor?: Maybe<Scalars['String']['output']>;
  hasNextPage: Scalars['Boolean']['output'];
};

export type Portfolio = {
  __typename?: 'Portfolio';
  balance: Balance;
  history: Array<WalletHistoryEntry>;
  internalTransfers: Array<InternalTransfer>;
  utxos: Array<Utxo>;
  walletCount: Scalars['Int']['output'];
};

export type Posting = {
  __typename?: 'Posting';
  accountCode: Scalars['String']['output'];
  amountSats: Scalars['Sats']['output'];
  asset: Scalars['String']['output'];
  direction: Scalars['String']['output'];
  id: Scalars['ID']['output'];
};

export type PostingResult = {
  __typename?: 'PostingResult';
  journal: Journal;
  status: Scalars['String']['output'];
};

export type ReconciliationItem = {
  __typename?: 'ReconciliationItem';
  amountSats?: Maybe<Scalars['Sats']['output']>;
  discrepancyKind?: Maybe<Scalars['String']['output']>;
  id: Scalars['ID']['output'];
  matchKey: Scalars['String']['output'];
  reason: Scalars['String']['output'];
  records?: Maybe<Scalars['JSON']['output']>;
  state: Scalars['String']['output'];
  txid?: Maybe<Scalars['String']['output']>;
  vout?: Maybe<Scalars['Int']['output']>;
};

export type ReconciliationRun = {
  __typename?: 'ReconciliationRun';
  completeness: Scalars['String']['output'];
  environmentId: Scalars['ID']['output'];
  error?: Maybe<Scalars['String']['output']>;
  finishedAt?: Maybe<Scalars['DateTime']['output']>;
  id: Scalars['ID']['output'];
  insertedAt: Scalars['DateTime']['output'];
  items: Array<ReconciliationItem>;
  policy?: Maybe<Scalars['JSON']['output']>;
  policyName: Scalars['String']['output'];
  policyVersion: Scalars['Int']['output'];
  referenceHash?: Maybe<Scalars['String']['output']>;
  referenceHeight?: Maybe<Scalars['Int']['output']>;
  sources?: Maybe<Scalars['JSON']['output']>;
  startedAt?: Maybe<Scalars['DateTime']['output']>;
  status: Scalars['String']['output'];
  summary?: Maybe<Scalars['JSON']['output']>;
  trigger: Scalars['String']['output'];
};


export type ReconciliationRunItemsArgs = {
  limit?: InputMaybe<Scalars['Int']['input']>;
  state?: InputMaybe<Scalars['String']['input']>;
};

export type RootMutationType = {
  __typename?: 'RootMutationType';
  abortExperiment?: Maybe<ExperimentRun>;
  addDiscrepancyNote?: Maybe<DiscrepancyNote>;
  addWatchedAddress?: Maybe<Wallet>;
  applyConfig?: Maybe<ConfigApplyResult>;
  compensateJournal?: Maybe<PostingResult>;
  createEnvironment?: Maybe<Environment>;
  createUser?: Maybe<User>;
  createWallet?: Maybe<Wallet>;
  deleteAlertPolicy?: Maybe<Scalars['Boolean']['output']>;
  deleteConfig?: Maybe<Scalars['Boolean']['output']>;
  deleteDashboard?: Maybe<Scalars['Boolean']['output']>;
  deleteIntegration?: Maybe<Scalars['Boolean']['output']>;
  deleteWallet?: Maybe<Scalars['Boolean']['output']>;
  internalTransfer?: Maybe<PostingResult>;
  planConfig?: Maybe<ConfigPlan>;
  putSecret?: Maybe<Scalars['Boolean']['output']>;
  reapplyConfig?: Maybe<ConfigApplyResult>;
  replayEvents?: Maybe<Scalars['Boolean']['output']>;
  requestWithdrawal?: Maybe<PostingResult>;
  restoreDefaultDashboard?: Maybe<Dashboard>;
  retryAlertDelivery?: Maybe<Scalars['Boolean']['output']>;
  runReconciliation?: Maybe<ReconciliationRun>;
  saveAlertPolicy?: Maybe<AlertPolicy>;
  saveDashboard?: Maybe<Dashboard>;
  saveIntegration?: Maybe<Integration>;
  setMembership?: Maybe<Scalars['Boolean']['output']>;
  settleWithdrawal?: Maybe<PostingResult>;
  startExperiment?: Maybe<ExperimentRun>;
  syncChain?: Maybe<Scalars['Boolean']['output']>;
  testIntegration?: Maybe<ConnectionTest>;
  transitionDiscrepancy?: Maybe<Discrepancy>;
  updateAlert?: Maybe<AlertOccurrence>;
  updateLocale?: Maybe<User>;
  updateUser?: Maybe<User>;
  validateConfig: ConfigValidation;
};


export type RootMutationTypeAbortExperimentArgs = {
  id: Scalars['ID']['input'];
};


export type RootMutationTypeAddDiscrepancyNoteArgs = {
  body: Scalars['String']['input'];
  data?: InputMaybe<Scalars['JSON']['input']>;
  id: Scalars['ID']['input'];
  kind?: InputMaybe<Scalars['String']['input']>;
};


export type RootMutationTypeAddWatchedAddressArgs = {
  address: Scalars['String']['input'];
  label?: InputMaybe<Scalars['String']['input']>;
  walletId: Scalars['ID']['input'];
};


export type RootMutationTypeApplyConfigArgs = {
  document: Scalars['JSON']['input'];
  expectedRevision?: InputMaybe<Scalars['Int']['input']>;
  message?: InputMaybe<Scalars['String']['input']>;
};


export type RootMutationTypeCompensateJournalArgs = {
  environmentId: Scalars['ID']['input'];
  journalId: Scalars['ID']['input'];
  reason: Scalars['String']['input'];
};


export type RootMutationTypeCreateEnvironmentArgs = {
  name: Scalars['String']['input'];
  requiredConfirmations?: InputMaybe<Scalars['Int']['input']>;
  slug: Scalars['String']['input'];
};


export type RootMutationTypeCreateUserArgs = {
  email: Scalars['String']['input'];
  environmentId?: InputMaybe<Scalars['ID']['input']>;
  name: Scalars['String']['input'];
  password: Scalars['String']['input'];
  role: Scalars['String']['input'];
};


export type RootMutationTypeCreateWalletArgs = {
  environmentId: Scalars['ID']['input'];
  input: WalletInput;
};


export type RootMutationTypeDeleteAlertPolicyArgs = {
  id: Scalars['ID']['input'];
};


export type RootMutationTypeDeleteConfigArgs = {
  kind: Scalars['String']['input'];
  name: Scalars['String']['input'];
};


export type RootMutationTypeDeleteDashboardArgs = {
  id: Scalars['ID']['input'];
};


export type RootMutationTypeDeleteIntegrationArgs = {
  id: Scalars['ID']['input'];
};


export type RootMutationTypeDeleteWalletArgs = {
  id: Scalars['ID']['input'];
};


export type RootMutationTypeInternalTransferArgs = {
  amountSats: Scalars['Sats']['input'];
  environmentId: Scalars['ID']['input'];
  fromRef: Scalars['String']['input'];
  idempotencyKey: Scalars['String']['input'];
  toRef: Scalars['String']['input'];
};


export type RootMutationTypePlanConfigArgs = {
  document: Scalars['JSON']['input'];
};


export type RootMutationTypePutSecretArgs = {
  environmentId: Scalars['ID']['input'];
  name: Scalars['String']['input'];
  value: Scalars['String']['input'];
};


export type RootMutationTypeReapplyConfigArgs = {
  kind: Scalars['String']['input'];
  name: Scalars['String']['input'];
  revision: Scalars['Int']['input'];
};


export type RootMutationTypeReplayEventsArgs = {
  consumer: Scalars['String']['input'];
  fromSeq: Scalars['Int']['input'];
};


export type RootMutationTypeRequestWithdrawalArgs = {
  accountRef: Scalars['String']['input'];
  amountSats: Scalars['Sats']['input'];
  environmentId: Scalars['ID']['input'];
  feeSats?: InputMaybe<Scalars['Sats']['input']>;
  idempotencyKey: Scalars['String']['input'];
};


export type RootMutationTypeRestoreDefaultDashboardArgs = {
  workspace: Scalars['String']['input'];
};


export type RootMutationTypeRetryAlertDeliveryArgs = {
  id: Scalars['ID']['input'];
};


export type RootMutationTypeRunReconciliationArgs = {
  environmentId: Scalars['ID']['input'];
};


export type RootMutationTypeSaveAlertPolicyArgs = {
  environmentId: Scalars['ID']['input'];
  input: AlertPolicyInput;
};


export type RootMutationTypeSaveDashboardArgs = {
  lockVersion?: InputMaybe<Scalars['Int']['input']>;
  name: Scalars['String']['input'];
  spec: Scalars['JSON']['input'];
};


export type RootMutationTypeSaveIntegrationArgs = {
  environmentId: Scalars['ID']['input'];
  input: IntegrationInput;
};


export type RootMutationTypeSetMembershipArgs = {
  environmentId: Scalars['ID']['input'];
  role: Scalars['String']['input'];
  userId: Scalars['ID']['input'];
};


export type RootMutationTypeSettleWithdrawalArgs = {
  environmentId: Scalars['ID']['input'];
  idempotencyKey: Scalars['String']['input'];
  outcome: Scalars['String']['input'];
  reason?: InputMaybe<Scalars['String']['input']>;
  txid?: InputMaybe<Scalars['String']['input']>;
};


export type RootMutationTypeStartExperimentArgs = {
  environmentId: Scalars['ID']['input'];
  scenarioId: Scalars['ID']['input'];
  seed?: InputMaybe<Scalars['Int']['input']>;
};


export type RootMutationTypeSyncChainArgs = {
  environmentId: Scalars['ID']['input'];
};


export type RootMutationTypeTestIntegrationArgs = {
  id: Scalars['ID']['input'];
};


export type RootMutationTypeTransitionDiscrepancyArgs = {
  id: Scalars['ID']['input'];
  note?: InputMaybe<Scalars['String']['input']>;
  state: Scalars['String']['input'];
};


export type RootMutationTypeUpdateAlertArgs = {
  action: Scalars['String']['input'];
  id: Scalars['ID']['input'];
};


export type RootMutationTypeUpdateLocaleArgs = {
  locale: Scalars['String']['input'];
};


export type RootMutationTypeUpdateUserArgs = {
  disabled?: InputMaybe<Scalars['Boolean']['input']>;
  id: Scalars['ID']['input'];
  role?: InputMaybe<Scalars['String']['input']>;
};


export type RootMutationTypeValidateConfigArgs = {
  document?: InputMaybe<Scalars['JSON']['input']>;
  yaml?: InputMaybe<Scalars['String']['input']>;
};

export type RootQueryType = {
  __typename?: 'RootQueryType';
  alertPolicies: Array<AlertPolicy>;
  alerts: Array<AlertOccurrence>;
  auditLog: Array<AuditEntry>;
  blocks: Array<Block>;
  chainOverview: ChainOverview;
  configResource?: Maybe<ConfigResource>;
  configResources: Array<ConfigResource>;
  configSchema: Scalars['JSON']['output'];
  customerBalances: Array<CustomerBalance>;
  dashboards: Array<Dashboard>;
  discrepancies: Array<Discrepancy>;
  discrepancy?: Maybe<Discrepancy>;
  environment?: Maybe<Environment>;
  environments: Array<Environment>;
  eventConsumers: Array<ConsumerCheckpoint>;
  events: Array<DomainEvent>;
  experimentActions: Array<ActionDescriptor>;
  experimentRun?: Maybe<ExperimentRun>;
  experimentRuns: Array<ExperimentRun>;
  financialRules: Array<FinancialRule>;
  integration?: Maybe<Integration>;
  integrationKinds: Array<Scalars['String']['output']>;
  integrations: Array<Integration>;
  jobStats: Array<JobStat>;
  jobs: Array<Job>;
  journals: Array<Journal>;
  ledgerAccounts: Array<LedgerAccount>;
  ledgerInvariants: LedgerInvariants;
  ledgerOperations: Array<LedgerOperation>;
  me?: Maybe<User>;
  nodes: Array<NodeStatus>;
  operationTimeline: OperationTimeline;
  overview: Overview;
  portfolio: Portfolio;
  reconciliationRun?: Maybe<ReconciliationRun>;
  reconciliationRuns: Array<ReconciliationRun>;
  runtimeCapabilities: Array<Scalars['String']['output']>;
  scenario?: Maybe<Scenario>;
  scenarios: Array<Scenario>;
  secretNames: Array<Scalars['String']['output']>;
  transaction?: Maybe<Transaction>;
  transactionVolume: Array<VolumeBucket>;
  transactions: TransactionConnection;
  users: Array<User>;
  wallets: Array<Wallet>;
  widgetTypes: Array<WidgetType>;
};


export type RootQueryTypeAlertPoliciesArgs = {
  environmentId: Scalars['ID']['input'];
};


export type RootQueryTypeAlertsArgs = {
  environmentId: Scalars['ID']['input'];
  limit?: InputMaybe<Scalars['Int']['input']>;
  state?: InputMaybe<Scalars['String']['input']>;
};


export type RootQueryTypeAuditLogArgs = {
  action?: InputMaybe<Scalars['String']['input']>;
  beforeId?: InputMaybe<Scalars['Int']['input']>;
  correlationId?: InputMaybe<Scalars['ID']['input']>;
  environmentId?: InputMaybe<Scalars['ID']['input']>;
  limit?: InputMaybe<Scalars['Int']['input']>;
  resourceId?: InputMaybe<Scalars['String']['input']>;
};


export type RootQueryTypeBlocksArgs = {
  beforeHeight?: InputMaybe<Scalars['Int']['input']>;
  environmentId: Scalars['ID']['input'];
  includeStale?: InputMaybe<Scalars['Boolean']['input']>;
  limit?: InputMaybe<Scalars['Int']['input']>;
};


export type RootQueryTypeChainOverviewArgs = {
  environmentId: Scalars['ID']['input'];
};


export type RootQueryTypeConfigResourceArgs = {
  kind: Scalars['String']['input'];
  name: Scalars['String']['input'];
};


export type RootQueryTypeConfigResourcesArgs = {
  kind?: InputMaybe<Scalars['String']['input']>;
};


export type RootQueryTypeConfigSchemaArgs = {
  kind: Scalars['String']['input'];
};


export type RootQueryTypeCustomerBalancesArgs = {
  environmentId: Scalars['ID']['input'];
};


export type RootQueryTypeDashboardsArgs = {
  workspace: Scalars['String']['input'];
};


export type RootQueryTypeDiscrepanciesArgs = {
  environmentId: Scalars['ID']['input'];
  kind?: InputMaybe<Scalars['String']['input']>;
  limit?: InputMaybe<Scalars['Int']['input']>;
  states?: InputMaybe<Array<Scalars['String']['input']>>;
};


export type RootQueryTypeDiscrepancyArgs = {
  id: Scalars['ID']['input'];
};


export type RootQueryTypeEnvironmentArgs = {
  id: Scalars['ID']['input'];
};


export type RootQueryTypeEventsArgs = {
  aggregateId?: InputMaybe<Scalars['String']['input']>;
  beforeSeq?: InputMaybe<Scalars['Int']['input']>;
  correlationId?: InputMaybe<Scalars['ID']['input']>;
  environmentId: Scalars['ID']['input'];
  limit?: InputMaybe<Scalars['Int']['input']>;
  types?: InputMaybe<Array<Scalars['String']['input']>>;
};


export type RootQueryTypeExperimentRunArgs = {
  id: Scalars['ID']['input'];
};


export type RootQueryTypeExperimentRunsArgs = {
  environmentId: Scalars['ID']['input'];
  limit?: InputMaybe<Scalars['Int']['input']>;
};


export type RootQueryTypeIntegrationArgs = {
  id: Scalars['ID']['input'];
};


export type RootQueryTypeIntegrationsArgs = {
  environmentId: Scalars['ID']['input'];
  kind?: InputMaybe<Scalars['String']['input']>;
};


export type RootQueryTypeJobsArgs = {
  limit?: InputMaybe<Scalars['Int']['input']>;
  queue?: InputMaybe<Scalars['String']['input']>;
  state?: InputMaybe<Scalars['String']['input']>;
};


export type RootQueryTypeJournalsArgs = {
  before?: InputMaybe<Scalars['DateTime']['input']>;
  correlationId?: InputMaybe<Scalars['ID']['input']>;
  environmentId: Scalars['ID']['input'];
  limit?: InputMaybe<Scalars['Int']['input']>;
  operationId?: InputMaybe<Scalars['String']['input']>;
};


export type RootQueryTypeLedgerAccountsArgs = {
  environmentId: Scalars['ID']['input'];
};


export type RootQueryTypeLedgerInvariantsArgs = {
  environmentId: Scalars['ID']['input'];
};


export type RootQueryTypeLedgerOperationsArgs = {
  environmentId: Scalars['ID']['input'];
  kind?: InputMaybe<Scalars['String']['input']>;
  limit?: InputMaybe<Scalars['Int']['input']>;
  state?: InputMaybe<Scalars['String']['input']>;
  txid?: InputMaybe<Scalars['String']['input']>;
};


export type RootQueryTypeNodesArgs = {
  environmentId: Scalars['ID']['input'];
};


export type RootQueryTypeOperationTimelineArgs = {
  environmentId: Scalars['ID']['input'];
  operationId: Scalars['String']['input'];
};


export type RootQueryTypeOverviewArgs = {
  environmentId: Scalars['ID']['input'];
};


export type RootQueryTypePortfolioArgs = {
  environmentId: Scalars['ID']['input'];
  walletIds?: InputMaybe<Array<Scalars['ID']['input']>>;
};


export type RootQueryTypeReconciliationRunArgs = {
  id: Scalars['ID']['input'];
};


export type RootQueryTypeReconciliationRunsArgs = {
  environmentId: Scalars['ID']['input'];
  limit?: InputMaybe<Scalars['Int']['input']>;
};


export type RootQueryTypeRuntimeCapabilitiesArgs = {
  environmentId: Scalars['ID']['input'];
};


export type RootQueryTypeScenarioArgs = {
  id: Scalars['ID']['input'];
};


export type RootQueryTypeSecretNamesArgs = {
  environmentId: Scalars['ID']['input'];
};


export type RootQueryTypeTransactionArgs = {
  environmentId: Scalars['ID']['input'];
  txid: Scalars['String']['input'];
};


export type RootQueryTypeTransactionVolumeArgs = {
  environmentId: Scalars['ID']['input'];
  hours?: InputMaybe<Scalars['Int']['input']>;
};


export type RootQueryTypeTransactionsArgs = {
  after?: InputMaybe<Scalars['String']['input']>;
  environmentId: Scalars['ID']['input'];
  filter?: InputMaybe<TransactionFilter>;
  first?: InputMaybe<Scalars['Int']['input']>;
};


export type RootQueryTypeWalletsArgs = {
  environmentId: Scalars['ID']['input'];
};

export type Scenario = {
  __typename?: 'Scenario';
  description?: Maybe<Scalars['String']['output']>;
  guarantee?: Maybe<Scalars['String']['output']>;
  id: Scalars['ID']['output'];
  insertedAt?: Maybe<Scalars['DateTime']['output']>;
  name: Scalars['String']['output'];
  requiredCapabilities: Array<Scalars['String']['output']>;
  spec?: Maybe<Scalars['JSON']['output']>;
  title: Scalars['String']['output'];
  version: Scalars['Int']['output'];
  versions: Array<Scalars['Int']['output']>;
};

export type StatusChange = {
  __typename?: 'StatusChange';
  blockHash?: Maybe<Scalars['String']['output']>;
  blockHeight?: Maybe<Scalars['Int']['output']>;
  eventId?: Maybe<Scalars['ID']['output']>;
  fromStatus?: Maybe<Scalars['String']['output']>;
  insertedAt: Scalars['DateTime']['output'];
  reason?: Maybe<Scalars['String']['output']>;
  toStatus: Scalars['String']['output'];
};

export type Transaction = {
  __typename?: 'Transaction';
  blockHash?: Maybe<Scalars['String']['output']>;
  blockHeight?: Maybe<Scalars['Int']['output']>;
  confirmations: Scalars['Int']['output'];
  conflictsWith?: Maybe<Array<Maybe<Scalars['String']['output']>>>;
  environmentId: Scalars['ID']['output'];
  events: Array<DomainEvent>;
  feeSats?: Maybe<Scalars['Sats']['output']>;
  firstSeenAt: Scalars['DateTime']['output'];
  id: Scalars['ID']['output'];
  inputs: Array<TxInput>;
  isCoinbase: Scalars['Boolean']['output'];
  operations: Array<LedgerOperation>;
  outputs: Array<TxOutput>;
  reconciliationStatus?: Maybe<Scalars['String']['output']>;
  replacedByTxid?: Maybe<Scalars['String']['output']>;
  status: Scalars['String']['output'];
  statusChangedAt: Scalars['DateTime']['output'];
  statusHistory: Array<StatusChange>;
  totalOutSats?: Maybe<Scalars['Sats']['output']>;
  txid: Scalars['String']['output'];
  vsize?: Maybe<Scalars['Int']['output']>;
};

export type TransactionConnection = {
  __typename?: 'TransactionConnection';
  nodes: Array<Transaction>;
  pageInfo: PageInfo;
};

export type TransactionFilter = {
  address?: InputMaybe<Scalars['String']['input']>;
  includeCoinbase?: InputMaybe<Scalars['Boolean']['input']>;
  search?: InputMaybe<Scalars['String']['input']>;
  status?: InputMaybe<Scalars['String']['input']>;
  watchedOnly?: InputMaybe<Scalars['Boolean']['input']>;
};

export type TxInput = {
  __typename?: 'TxInput';
  address?: Maybe<Scalars['String']['output']>;
  prevTxid?: Maybe<Scalars['String']['output']>;
  prevVout?: Maybe<Scalars['Int']['output']>;
  valueSats?: Maybe<Scalars['Sats']['output']>;
  vin: Scalars['Int']['output'];
  watched?: Maybe<Scalars['JSON']['output']>;
};

export type TxOutput = {
  __typename?: 'TxOutput';
  address?: Maybe<Scalars['String']['output']>;
  scriptType?: Maybe<Scalars['String']['output']>;
  spentByTxid?: Maybe<Scalars['String']['output']>;
  valueSats: Scalars['Sats']['output'];
  vout: Scalars['Int']['output'];
  watched?: Maybe<Scalars['JSON']['output']>;
};

export type User = {
  __typename?: 'User';
  disabledAt?: Maybe<Scalars['DateTime']['output']>;
  email: Scalars['String']['output'];
  id: Scalars['ID']['output'];
  insertedAt?: Maybe<Scalars['DateTime']['output']>;
  locale: Scalars['String']['output'];
  name: Scalars['String']['output'];
  role: Scalars['String']['output'];
};

export type Utxo = {
  __typename?: 'Utxo';
  address?: Maybe<Scalars['String']['output']>;
  blockHeight?: Maybe<Scalars['Int']['output']>;
  spentUnconfirmed: Scalars['Boolean']['output'];
  status: Scalars['String']['output'];
  txid: Scalars['String']['output'];
  valueSats: Scalars['Sats']['output'];
  vout: Scalars['Int']['output'];
};

export type VolumeBucket = {
  __typename?: 'VolumeBucket';
  bucket: Scalars['DateTime']['output'];
  count: Scalars['Int']['output'];
  valueSats: Scalars['Sats']['output'];
};

export type Wallet = {
  __typename?: 'Wallet';
  accountRef?: Maybe<Scalars['String']['output']>;
  addresses: Array<WatchedAddress>;
  balance: Balance;
  derivationLimit: Scalars['Int']['output'];
  descriptor?: Maybe<Scalars['String']['output']>;
  environmentId: Scalars['ID']['output'];
  groupName?: Maybe<Scalars['String']['output']>;
  id: Scalars['ID']['output'];
  kind: Scalars['String']['output'];
  labels: Array<Scalars['String']['output']>;
  name: Scalars['String']['output'];
};

export type WalletHistoryEntry = {
  __typename?: 'WalletHistoryEntry';
  blockHeight?: Maybe<Scalars['Int']['output']>;
  firstSeenAt?: Maybe<Scalars['DateTime']['output']>;
  receivedSats: Scalars['Sats']['output'];
  sentSats: Scalars['Sats']['output'];
  status: Scalars['String']['output'];
  txid: Scalars['String']['output'];
};

export type WalletInput = {
  accountRef?: InputMaybe<Scalars['String']['input']>;
  addresses?: InputMaybe<Array<Scalars['String']['input']>>;
  derivationLimit?: InputMaybe<Scalars['Int']['input']>;
  descriptor?: InputMaybe<Scalars['String']['input']>;
  groupName?: InputMaybe<Scalars['String']['input']>;
  kind: Scalars['String']['input'];
  labels?: InputMaybe<Array<Scalars['String']['input']>>;
  name: Scalars['String']['input'];
};

export type WatchedAddress = {
  __typename?: 'WatchedAddress';
  address: Scalars['String']['output'];
  derivationIndex?: Maybe<Scalars['Int']['output']>;
  label?: Maybe<Scalars['String']['output']>;
};

export type WidgetType = {
  __typename?: 'WidgetType';
  context: Scalars['String']['output'];
  minHeight: Scalars['Int']['output'];
  minWidth: Scalars['Int']['output'];
  permission: Scalars['String']['output'];
  refresh: Scalars['String']['output'];
  type: Scalars['String']['output'];
  workspaces: Array<Scalars['String']['output']>;
};

export type ZmqCheckpoint = {
  __typename?: 'ZmqCheckpoint';
  duplicatesTotal: Scalars['Int']['output'];
  gapsTotal: Scalars['Int']['output'];
  lastSequence?: Maybe<Scalars['Int']['output']>;
  updatedAt?: Maybe<Scalars['DateTime']['output']>;
};

export type AlertsQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type AlertsQuery = { __typename?: 'RootQueryType', alerts: Array<{ __typename?: 'AlertOccurrence', id: string, title: string, state: string, severity: string, count: number, firstSeenAt: string, lastSeenAt: string, policyName?: string | null, details?: any | null, deliveries: Array<{ __typename?: 'AlertDelivery', id: string, destination: string, status: string, attempts: number, lastError?: string | null }> }>, alertPolicies: Array<{ __typename?: 'AlertPolicy', id: string, name: string, eventTypes: Array<string>, severity: string, cooldownSeconds: number, destinations?: any | null, enabled: boolean }> };

export type UpdateAlertMutationVariables = Exact<{
  id: Scalars['ID']['input'];
  action: Scalars['String']['input'];
}>;


export type UpdateAlertMutation = { __typename?: 'RootMutationType', updateAlert?: { __typename?: 'AlertOccurrence', id: string, state: string } | null };

export type RetryAlertDeliveryMutationVariables = Exact<{
  id: Scalars['ID']['input'];
}>;


export type RetryAlertDeliveryMutation = { __typename?: 'RootMutationType', retryAlertDelivery?: boolean | null };

export type SaveAlertPolicyMutationVariables = Exact<{
  environmentId: Scalars['ID']['input'];
  input: AlertPolicyInput;
}>;


export type SaveAlertPolicyMutation = { __typename?: 'RootMutationType', saveAlertPolicy?: { __typename?: 'AlertPolicy', id: string } | null };

export type OperationTimelineQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
  operationId: Scalars['String']['input'];
}>;


export type OperationTimelineQuery = { __typename?: 'RootQueryType', operationTimeline: { __typename?: 'OperationTimeline', operation?: { __typename?: 'LedgerOperation', operationId: string, kind: string, state: string, accountRef?: string | null, amountSats: number, txid?: string | null, vout?: number | null, generation: number } | null, journals: Array<{ __typename?: 'Journal', id: string, entryKind: string, ruleName: string, ruleVersion: number, description?: string | null, postedAt: string, correlationId?: string | null, postings: Array<{ __typename?: 'Posting', id: string, accountCode: string, direction: string, amountSats: number }> }>, events: Array<{ __typename?: 'DomainEvent', id: string, seq: number, eventType: string, observedAt: string, aggregateId: string, correlationId: string, payload?: any | null }> } };

export type AuditLogQueryVariables = Exact<{
  environmentId?: InputMaybe<Scalars['ID']['input']>;
  action?: InputMaybe<Scalars['String']['input']>;
}>;


export type AuditLogQuery = { __typename?: 'RootQueryType', auditLog: Array<{ __typename?: 'AuditEntry', id: string, actorEmail?: string | null, action: string, resourceType?: string | null, resourceId?: string | null, changes?: any | null, ip?: string | null, insertedAt: string }> };

export type ChainOverviewQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type ChainOverviewQuery = { __typename?: 'RootQueryType', chainOverview: { __typename?: 'ChainOverview', checkpointHeight?: number | null, checkpointHash?: string | null, checkpointUpdatedAt?: string | null, mempoolSize: number, transactionCounts?: any | null, diverged: boolean, referenceNode?: string | null, requiredConfirmations: number, tip?: { __typename?: 'Block', height: number, hash: string, blockTime?: string | null } | null, reorganizations: Array<{ __typename?: 'DomainEvent', id: string, seq: number, observedAt: string, payload?: any | null, eventType: string, schemaVersion: number, aggregateType: string, aggregateId: string, correlationId: string, causationId?: string | null }>, staleBlocks: Array<{ __typename?: 'Block', hash: string, height: number, disconnectedAt?: string | null }> } };

export type BlocksQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type BlocksQuery = { __typename?: 'RootQueryType', blocks: Array<{ __typename?: 'Block', hash: string, height: number, txCount: number, blockTime?: string | null, connectedAt?: string | null, inBestChain: boolean }> };

export type DomainEventsQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
  types?: InputMaybe<Array<Scalars['String']['input']> | Scalars['String']['input']>;
}>;


export type DomainEventsQuery = { __typename?: 'RootQueryType', events: Array<{ __typename?: 'DomainEvent', id: string, seq: number, eventType: string, schemaVersion: number, aggregateType: string, aggregateId: string, correlationId: string, causationId?: string | null, observedAt: string, payload?: any | null }> };

export type ConfigResourceQueryVariables = Exact<{
  kind: Scalars['String']['input'];
  name: Scalars['String']['input'];
}>;


export type ConfigResourceQuery = { __typename?: 'RootQueryType', configResource?: { __typename?: 'ConfigResource', id: string, kind: string, name: string, desiredRevision: number, appliedRevision?: number | null, status: string, statusMessage?: string | null, observed?: any | null, document?: any | null, updatedAt: string, revisions: Array<{ __typename?: 'ConfigRevision', revision: number, yaml: string, spec?: any | null, authorEmail?: string | null, message?: string | null, insertedAt: string }> } | null };

export type ValidateConfigMutationVariables = Exact<{
  yaml?: InputMaybe<Scalars['String']['input']>;
}>;


export type ValidateConfigMutation = { __typename?: 'RootMutationType', validateConfig: { __typename?: 'ConfigValidation', valid: boolean, document?: any | null, canonicalYaml?: string | null, errors: Array<{ __typename?: 'ConfigIssue', path?: string | null, message: string, line?: number | null, column?: number | null }> } };

export type PlanConfigMutationVariables = Exact<{
  document: Scalars['JSON']['input'];
}>;


export type PlanConfigMutation = { __typename?: 'RootMutationType', planConfig?: { __typename?: 'ConfigPlan', action: string, kind: string, name: string, currentRevision?: number | null, impact: Array<string>, canonicalYaml: string, currentYaml?: string | null, changes: Array<{ __typename?: 'ConfigChange', op: string, path: string, old?: any | null, new?: any | null }> } | null };

export type ApplyConfigMutationVariables = Exact<{
  document: Scalars['JSON']['input'];
  expectedRevision?: InputMaybe<Scalars['Int']['input']>;
  message?: InputMaybe<Scalars['String']['input']>;
}>;


export type ApplyConfigMutation = { __typename?: 'RootMutationType', applyConfig?: { __typename?: 'ConfigApplyResult', changed: boolean, resource: { __typename?: 'ConfigResource', kind: string, name: string, desiredRevision: number, appliedRevision?: number | null, status: string, statusMessage?: string | null } } | null };

export type ReapplyConfigMutationVariables = Exact<{
  kind: Scalars['String']['input'];
  name: Scalars['String']['input'];
  revision: Scalars['Int']['input'];
}>;


export type ReapplyConfigMutation = { __typename?: 'RootMutationType', reapplyConfig?: { __typename?: 'ConfigApplyResult', changed: boolean } | null };

export type ConfigResourcesQueryVariables = Exact<{
  kind?: InputMaybe<Scalars['String']['input']>;
}>;


export type ConfigResourcesQuery = { __typename?: 'RootQueryType', configResources: Array<{ __typename?: 'ConfigResource', id: string, kind: string, name: string, environmentRef?: string | null, desiredRevision: number, appliedRevision?: number | null, status: string, statusMessage?: string | null, updatedAt: string }> };

export type EnvironmentsQueryVariables = Exact<{ [key: string]: never; }>;


export type EnvironmentsQuery = { __typename?: 'RootQueryType', environments: Array<{ __typename?: 'Environment', id: string, slug: string, name: string, kind: string, network: string, status: string, requiredConfirmations: number, settings?: any | null, insertedAt?: string | null }> };

export type CreateEnvironmentMutationVariables = Exact<{
  slug: Scalars['String']['input'];
  name: Scalars['String']['input'];
  requiredConfirmations?: InputMaybe<Scalars['Int']['input']>;
}>;


export type CreateEnvironmentMutation = { __typename?: 'RootMutationType', createEnvironment?: { __typename?: 'Environment', id: string } | null };

export type ExperimentRunQueryVariables = Exact<{
  id: Scalars['ID']['input'];
}>;


export type ExperimentRunQuery = { __typename?: 'RootQueryType', experimentRun?: { __typename?: 'ExperimentRun', id: string, scenarioName: string, scenarioVersion: number, status: string, statusReason?: string | null, cleanupStatus: string, seed: string, startedAt?: string | null, finishedAt?: string | null, insertedAt: string, report?: any | null, steps: Array<{ __typename?: 'ExperimentStep', id: string, position: number, stepKey: string, phase: string, action: string, params?: any | null, status: string, attempts: number, maxAttempts: number, timeoutMs: number, checkpoint?: any | null, result?: any | null, failureReason?: string | null, startedAt?: string | null, finishedAt?: string | null }>, assertions: Array<{ __typename?: 'AssertionResult', id: string, position: number, type: string, params?: any | null, outcome: string, expected?: any | null, actual?: any | null, message?: string | null, attempts: number }> } | null };

export type AbortExperimentMutationVariables = Exact<{
  id: Scalars['ID']['input'];
}>;


export type AbortExperimentMutation = { __typename?: 'RootMutationType', abortExperiment?: { __typename?: 'ExperimentRun', id: string, status: string } | null };

export type ExperimentRunsQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type ExperimentRunsQuery = { __typename?: 'RootQueryType', runtimeCapabilities: Array<string>, scenarios: Array<{ __typename?: 'Scenario', id: string, name: string, version: number, title: string, description?: string | null, guarantee?: string | null, requiredCapabilities: Array<string>, versions: Array<number> }>, experimentActions: Array<{ __typename?: 'ActionDescriptor', name: string, idempotency: string, capabilities: Array<string> }>, experimentRuns: Array<{ __typename?: 'ExperimentRun', id: string, scenarioName: string, scenarioVersion: number, status: string, statusReason?: string | null, seed: string, startedAt?: string | null, finishedAt?: string | null, insertedAt: string }> };

export type StartExperimentMutationVariables = Exact<{
  environmentId: Scalars['ID']['input'];
  scenarioId: Scalars['ID']['input'];
  seed?: InputMaybe<Scalars['Int']['input']>;
}>;


export type StartExperimentMutation = { __typename?: 'RootMutationType', startExperiment?: { __typename?: 'ExperimentRun', id: string } | null };

export type IntegrationsQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type IntegrationsQuery = { __typename?: 'RootQueryType', secretNames: Array<string>, integrationKinds: Array<string>, integrations: Array<{ __typename?: 'Integration', id: string, name: string, kind: string, status: string, enabled: boolean, config?: any | null, secretRef?: string | null, health?: any | null, capabilities: Array<string>, checkpoint?: any | null, lastSyncAt?: string | null, lastError?: string | null, lockVersion: number, updatedAt?: string | null, errors: Array<{ __typename?: 'IntegrationError', message: string, occurredAt: string }> }> };

export type TestIntegrationMutationVariables = Exact<{
  id: Scalars['ID']['input'];
}>;


export type TestIntegrationMutation = { __typename?: 'RootMutationType', testIntegration?: { __typename?: 'ConnectionTest', ok: boolean, status: string, details?: any | null, error?: string | null } | null };

export type SaveIntegrationMutationVariables = Exact<{
  environmentId: Scalars['ID']['input'];
  input: IntegrationInput;
}>;


export type SaveIntegrationMutation = { __typename?: 'RootMutationType', saveIntegration?: { __typename?: 'Integration', id: string } | null };

export type DeleteIntegrationMutationVariables = Exact<{
  id: Scalars['ID']['input'];
}>;


export type DeleteIntegrationMutation = { __typename?: 'RootMutationType', deleteIntegration?: boolean | null };

export type PutSecretMutationVariables = Exact<{
  environmentId: Scalars['ID']['input'];
  name: Scalars['String']['input'];
  value: Scalars['String']['input'];
}>;


export type PutSecretMutation = { __typename?: 'RootMutationType', putSecret?: boolean | null };

export type JobsQueryVariables = Exact<{
  state?: InputMaybe<Scalars['String']['input']>;
}>;


export type JobsQuery = { __typename?: 'RootQueryType', jobStats: Array<{ __typename?: 'JobStat', queue: string, state: string, count: number }>, eventConsumers: Array<{ __typename?: 'ConsumerCheckpoint', consumer: string, lastSeq: number, lag: number, updatedAt?: string | null }>, jobs: Array<{ __typename?: 'Job', id: string, queue: string, worker: string, state: string, attempt: number, maxAttempts: number, errors?: any | null, insertedAt?: string | null, attemptedAt?: string | null, completedAt?: string | null }> };

export type ReplayEventsMutationVariables = Exact<{
  consumer: Scalars['String']['input'];
  fromSeq: Scalars['Int']['input'];
}>;


export type ReplayEventsMutation = { __typename?: 'RootMutationType', replayEvents?: boolean | null };

export type LedgerAccountsQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type LedgerAccountsQuery = { __typename?: 'RootQueryType', ledgerAccounts: Array<{ __typename?: 'LedgerAccount', id: string, code: string, type: string, normalBalance: string, restricted: boolean, ownerRef?: string | null, balanceSats: number, debitTotal: number, creditTotal: number }>, ledgerInvariants: { __typename?: 'LedgerInvariants', ok: boolean, balanced: boolean, totalDebits: number, totalCredits: number, unbalancedJournals: Array<string>, projectionDrift?: any | null, negativeRestricted?: any | null, duplicateCredits: number }, financialRules: Array<{ __typename?: 'FinancialRule', name: string, version: number, current: boolean }>, customerBalances: Array<{ __typename?: 'CustomerBalance', accountRef: string, availableSats: number, pendingSats: number, reservedSats: number }> };

export type JournalsQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type JournalsQuery = { __typename?: 'RootQueryType', journals: Array<{ __typename?: 'Journal', id: string, operationId: string, entryKind: string, ruleName: string, ruleVersion: number, description?: string | null, reversesJournalId?: string | null, postedAt: string, metadata?: any | null, postings: Array<{ __typename?: 'Posting', id: string, accountCode: string, direction: string, amountSats: number }> }> };

export type LedgerOperationsQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type LedgerOperationsQuery = { __typename?: 'RootQueryType', ledgerOperations: Array<{ __typename?: 'LedgerOperation', id: string, operationId: string, kind: string, state: string, accountRef?: string | null, amountSats: number, feeSats: number, txid?: string | null, generation: number, updatedAt?: string | null }> };

export type CompensateJournalMutationVariables = Exact<{
  environmentId: Scalars['ID']['input'];
  journalId: Scalars['ID']['input'];
  reason: Scalars['String']['input'];
}>;


export type CompensateJournalMutation = { __typename?: 'RootMutationType', compensateJournal?: { __typename?: 'PostingResult', status: string } | null };

export type RequestWithdrawalMutationVariables = Exact<{
  environmentId: Scalars['ID']['input'];
  accountRef: Scalars['String']['input'];
  amountSats: Scalars['Sats']['input'];
  idempotencyKey: Scalars['String']['input'];
}>;


export type RequestWithdrawalMutation = { __typename?: 'RootMutationType', requestWithdrawal?: { __typename?: 'PostingResult', status: string } | null };

export type InternalTransferMutationVariables = Exact<{
  environmentId: Scalars['ID']['input'];
  fromRef: Scalars['String']['input'];
  toRef: Scalars['String']['input'];
  amountSats: Scalars['Sats']['input'];
  idempotencyKey: Scalars['String']['input'];
}>;


export type InternalTransferMutation = { __typename?: 'RootMutationType', internalTransfer?: { __typename?: 'PostingResult', status: string } | null };

export type NodesQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type NodesQuery = { __typename?: 'RootQueryType', nodes: Array<{ __typename?: 'NodeStatus', isReference: boolean, integration: { __typename?: 'Integration', id: string, name: string, status: string, config?: any | null, lastError?: string | null, lastSyncAt?: string | null }, latest?: { __typename?: 'NodeObservation', reachable: boolean, chain?: string | null, height?: number | null, bestHash?: string | null, chainwork?: string | null, peers?: number | null, mempoolSize?: number | null, rpcLatencyMs?: number | null, observedAt: string, error?: string | null, initialBlockDownload?: boolean | null } | null, history: Array<{ __typename?: 'NodeObservation', observedAt: string, height?: number | null, rpcLatencyMs?: number | null, reachable: boolean }>, downtime: Array<{ __typename?: 'DomainEvent', id: string, eventType: string, observedAt: string, payload?: any | null }>, zmq?: { __typename?: 'ZmqCheckpoint', lastSequence?: number | null, gapsTotal: number, duplicatesTotal: number, updatedAt?: string | null } | null }>, chainOverview: { __typename?: 'ChainOverview', diverged: boolean, referenceNode?: string | null, tip?: { __typename?: 'Block', height: number, hash: string } | null } };

export type SyncChainMutationVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type SyncChainMutation = { __typename?: 'RootMutationType', syncChain?: boolean | null };

export type DashboardsQueryVariables = Exact<{
  workspace: Scalars['String']['input'];
}>;


export type DashboardsQuery = { __typename?: 'RootQueryType', dashboards: Array<{ __typename?: 'Dashboard', id: string, name: string, title: string, workspace: string, spec: any, isDefault: boolean, shared: boolean, lockVersion: number }>, widgetTypes: Array<{ __typename?: 'WidgetType', type: string, minWidth: number, minHeight: number, permission: string, workspaces: Array<string>, refresh: string }> };

export type SaveDashboardMutationVariables = Exact<{
  name: Scalars['String']['input'];
  spec: Scalars['JSON']['input'];
  lockVersion?: InputMaybe<Scalars['Int']['input']>;
}>;


export type SaveDashboardMutation = { __typename?: 'RootMutationType', saveDashboard?: { __typename?: 'Dashboard', id: string, lockVersion: number } | null };

export type RestoreDashboardMutationVariables = Exact<{
  workspace: Scalars['String']['input'];
}>;


export type RestoreDashboardMutation = { __typename?: 'RootMutationType', restoreDefaultDashboard?: { __typename?: 'Dashboard', id: string } | null };

export type OverviewQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type OverviewQuery = { __typename?: 'RootQueryType', overview: { __typename?: 'Overview', confirmedSats: number, pendingSats: number, utxoCount: number, tipHeight?: number | null, tipHash?: string | null, tipTime?: string | null, mempoolSize: number, openDiscrepancies: number, firingAlerts: number, ingestionLagBlocks?: number | null, ingestionLatencyMs?: number | null, lastReconciliation?: { __typename?: 'ReconciliationRun', id: string, status: string, completeness: string, summary?: any | null, finishedAt?: string | null } | null, activeExperiments: Array<{ __typename?: 'ExperimentRun', id: string, scenarioName: string, status: string, startedAt?: string | null }>, recentExperiments: Array<{ __typename?: 'ExperimentRun', id: string, scenarioName: string, status: string, finishedAt?: string | null, statusReason?: string | null }> } };

export type WidgetNodesQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type WidgetNodesQuery = { __typename?: 'RootQueryType', nodes: Array<{ __typename?: 'NodeStatus', isReference: boolean, integration: { __typename?: 'Integration', id: string, name: string, status: string }, latest?: { __typename?: 'NodeObservation', reachable: boolean, height?: number | null, rpcLatencyMs?: number | null, peers?: number | null, observedAt: string } | null, history: Array<{ __typename?: 'NodeObservation', observedAt: string, rpcLatencyMs?: number | null, height?: number | null, reachable: boolean }> }> };

export type WidgetTransactionsQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type WidgetTransactionsQuery = { __typename?: 'RootQueryType', transactions: { __typename?: 'TransactionConnection', nodes: Array<{ __typename?: 'Transaction', id: string, txid: string, status: string, confirmations: number, totalOutSats?: number | null, firstSeenAt: string }> } };

export type WidgetVolumeQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type WidgetVolumeQuery = { __typename?: 'RootQueryType', transactionVolume: Array<{ __typename?: 'VolumeBucket', bucket: string, count: number, valueSats: number }> };

export type WidgetReconciliationQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type WidgetReconciliationQuery = { __typename?: 'RootQueryType', reconciliationRuns: Array<{ __typename?: 'ReconciliationRun', id: string, status: string, completeness: string, summary?: any | null, insertedAt: string, finishedAt?: string | null }> };

export type WidgetJobsQueryVariables = Exact<{ [key: string]: never; }>;


export type WidgetJobsQuery = { __typename?: 'RootQueryType', jobStats: Array<{ __typename?: 'JobStat', queue: string, state: string, count: number }> };

export type WidgetReorgsQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type WidgetReorgsQuery = { __typename?: 'RootQueryType', chainOverview: { __typename?: 'ChainOverview', reorganizations: Array<{ __typename?: 'DomainEvent', id: string, observedAt: string, payload?: any | null }> } };

export type DiscrepancyQueryVariables = Exact<{
  id: Scalars['ID']['input'];
}>;


export type DiscrepancyQuery = { __typename?: 'RootQueryType', discrepancy?: { __typename?: 'Discrepancy', id: string, environmentId: string, kind: string, state: string, severity: string, source?: string | null, matchKey: string, txid?: string | null, vout?: number | null, amountSats?: number | null, reason: string, evidence?: any | null, occurrences: number, firstRunId: string, lastRunId: string, resolution?: string | null, resolvedAt?: string | null, insertedAt: string, updatedAt: string, suggestion: string, notes: Array<{ __typename?: 'DiscrepancyNote', id: string, authorEmail?: string | null, kind: string, body: string, data?: any | null, insertedAt: string }> } | null };

export type TransitionDiscrepancyMutationVariables = Exact<{
  id: Scalars['ID']['input'];
  state: Scalars['String']['input'];
  note?: InputMaybe<Scalars['String']['input']>;
}>;


export type TransitionDiscrepancyMutation = { __typename?: 'RootMutationType', transitionDiscrepancy?: { __typename?: 'Discrepancy', id: string, state: string } | null };

export type AddDiscrepancyNoteMutationVariables = Exact<{
  id: Scalars['ID']['input'];
  body: Scalars['String']['input'];
  kind?: InputMaybe<Scalars['String']['input']>;
  data?: InputMaybe<Scalars['JSON']['input']>;
}>;


export type AddDiscrepancyNoteMutation = { __typename?: 'RootMutationType', addDiscrepancyNote?: { __typename?: 'DiscrepancyNote', id: string } | null };

export type ReconciliationRunsQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type ReconciliationRunsQuery = { __typename?: 'RootQueryType', reconciliationRuns: Array<{ __typename?: 'ReconciliationRun', id: string, status: string, completeness: string, trigger: string, policyName: string, policyVersion: number, summary?: any | null, referenceHeight?: number | null, startedAt?: string | null, finishedAt?: string | null, insertedAt: string }> };

export type DiscrepanciesQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
  states?: InputMaybe<Array<Scalars['String']['input']> | Scalars['String']['input']>;
}>;


export type DiscrepanciesQuery = { __typename?: 'RootQueryType', discrepancies: Array<{ __typename?: 'Discrepancy', id: string, kind: string, state: string, severity: string, source?: string | null, txid?: string | null, vout?: number | null, amountSats?: number | null, reason: string, occurrences: number, updatedAt: string }> };

export type RunReconciliationMutationVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type RunReconciliationMutation = { __typename?: 'RootMutationType', runReconciliation?: { __typename?: 'ReconciliationRun', id: string, status: string } | null };

export type ReconciliationRunQueryVariables = Exact<{
  id: Scalars['ID']['input'];
  state?: InputMaybe<Scalars['String']['input']>;
}>;


export type ReconciliationRunQuery = { __typename?: 'RootQueryType', reconciliationRun?: { __typename?: 'ReconciliationRun', id: string, status: string, completeness: string, trigger: string, policyName: string, policyVersion: number, policy?: any | null, referenceHeight?: number | null, referenceHash?: string | null, sources?: any | null, summary?: any | null, error?: string | null, startedAt?: string | null, finishedAt?: string | null, items: Array<{ __typename?: 'ReconciliationItem', id: string, matchKey: string, state: string, discrepancyKind?: string | null, reason: string, records?: any | null, amountSats?: number | null, txid?: string | null, vout?: number | null }> } | null };

export type UsersQueryVariables = Exact<{ [key: string]: never; }>;


export type UsersQuery = { __typename?: 'RootQueryType', users: Array<{ __typename?: 'User', id: string, email: string, name: string, role: string, disabledAt?: string | null, insertedAt?: string | null }> };

export type CreateUserMutationVariables = Exact<{
  email: Scalars['String']['input'];
  name: Scalars['String']['input'];
  role: Scalars['String']['input'];
  password: Scalars['String']['input'];
  environmentId?: InputMaybe<Scalars['ID']['input']>;
}>;


export type CreateUserMutation = { __typename?: 'RootMutationType', createUser?: { __typename?: 'User', id: string } | null };

export type UpdateUserMutationVariables = Exact<{
  id: Scalars['ID']['input'];
  role?: InputMaybe<Scalars['String']['input']>;
  disabled?: InputMaybe<Scalars['Boolean']['input']>;
}>;


export type UpdateUserMutation = { __typename?: 'RootMutationType', updateUser?: { __typename?: 'User', id: string } | null };

export type UpdateLocaleMutationVariables = Exact<{
  locale: Scalars['String']['input'];
}>;


export type UpdateLocaleMutation = { __typename?: 'RootMutationType', updateLocale?: { __typename?: 'User', locale: string } | null };

export type TransactionQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
  txid: Scalars['String']['input'];
}>;


export type TransactionQuery = { __typename?: 'RootQueryType', transaction?: { __typename?: 'Transaction', id: string, txid: string, status: string, blockHash?: string | null, blockHeight?: number | null, confirmations: number, feeSats?: number | null, vsize?: number | null, isCoinbase: boolean, replacedByTxid?: string | null, conflictsWith?: Array<string | null> | null, firstSeenAt: string, statusChangedAt: string, reconciliationStatus?: string | null, outputs: Array<{ __typename?: 'TxOutput', vout: number, valueSats: number, address?: string | null, scriptType?: string | null, spentByTxid?: string | null, watched?: any | null }>, inputs: Array<{ __typename?: 'TxInput', vin: number, prevTxid?: string | null, prevVout?: number | null, valueSats?: number | null, address?: string | null, watched?: any | null }>, statusHistory: Array<{ __typename?: 'StatusChange', fromStatus?: string | null, toStatus: string, blockHash?: string | null, blockHeight?: number | null, reason?: string | null, insertedAt: string }>, events: Array<{ __typename?: 'DomainEvent', id: string, seq: number, eventType: string, observedAt: string, correlationId: string }>, operations: Array<{ __typename?: 'LedgerOperation', id: string, operationId: string, kind: string, state: string, accountRef?: string | null, amountSats: number, generation: number }> } | null };

export type TransactionsQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
  filter?: InputMaybe<TransactionFilter>;
  after?: InputMaybe<Scalars['String']['input']>;
}>;


export type TransactionsQuery = { __typename?: 'RootQueryType', transactions: { __typename?: 'TransactionConnection', nodes: Array<{ __typename?: 'Transaction', id: string, txid: string, status: string, blockHeight?: number | null, confirmations: number, feeSats?: number | null, totalOutSats?: number | null, firstSeenAt: string, isCoinbase: boolean }>, pageInfo: { __typename?: 'PageInfo', endCursor?: string | null, hasNextPage: boolean } } };

export type WalletsQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type WalletsQuery = { __typename?: 'RootQueryType', wallets: Array<{ __typename?: 'Wallet', id: string, name: string, kind: string, descriptor?: string | null, groupName?: string | null, labels: Array<string>, accountRef?: string | null, derivationLimit: number, addresses: Array<{ __typename?: 'WatchedAddress', address: string, label?: string | null, derivationIndex?: number | null }>, balance: { __typename?: 'Balance', confirmedSats: number, pendingSats: number, utxoCount: number } }> };

export type PortfolioQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type PortfolioQuery = { __typename?: 'RootQueryType', portfolio: { __typename?: 'Portfolio', walletCount: number, balance: { __typename?: 'Balance', confirmedSats: number, pendingSats: number, utxoCount: number }, utxos: Array<{ __typename?: 'Utxo', txid: string, vout: number, address?: string | null, valueSats: number, status: string, blockHeight?: number | null, spentUnconfirmed: boolean }>, history: Array<{ __typename?: 'WalletHistoryEntry', txid: string, status: string, blockHeight?: number | null, firstSeenAt?: string | null, receivedSats: number, sentSats: number }>, internalTransfers: Array<{ __typename?: 'InternalTransfer', txid: string, fromWalletId: string, toWalletId: string, valueSats: number }> } };

export type CreateWalletMutationVariables = Exact<{
  environmentId: Scalars['ID']['input'];
  input: WalletInput;
}>;


export type CreateWalletMutation = { __typename?: 'RootMutationType', createWallet?: { __typename?: 'Wallet', id: string } | null };

export type DeleteWalletMutationVariables = Exact<{
  id: Scalars['ID']['input'];
}>;


export type DeleteWalletMutation = { __typename?: 'RootMutationType', deleteWallet?: boolean | null };

export type TopbarAlertsQueryVariables = Exact<{
  environmentId: Scalars['ID']['input'];
}>;


export type TopbarAlertsQuery = { __typename?: 'RootQueryType', alerts: Array<{ __typename?: 'AlertOccurrence', id: string, title: string, severity: string, state: string, lastSeenAt: string }> };


export const AlertsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Alerts"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"alerts"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"IntValue","value":"100"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"title"}},{"kind":"Field","name":{"kind":"Name","value":"state"}},{"kind":"Field","name":{"kind":"Name","value":"severity"}},{"kind":"Field","name":{"kind":"Name","value":"count"}},{"kind":"Field","name":{"kind":"Name","value":"firstSeenAt"}},{"kind":"Field","name":{"kind":"Name","value":"lastSeenAt"}},{"kind":"Field","name":{"kind":"Name","value":"policyName"}},{"kind":"Field","name":{"kind":"Name","value":"details"}},{"kind":"Field","name":{"kind":"Name","value":"deliveries"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"destination"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"attempts"}},{"kind":"Field","name":{"kind":"Name","value":"lastError"}}]}}]}},{"kind":"Field","name":{"kind":"Name","value":"alertPolicies"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"eventTypes"}},{"kind":"Field","name":{"kind":"Name","value":"severity"}},{"kind":"Field","name":{"kind":"Name","value":"cooldownSeconds"}},{"kind":"Field","name":{"kind":"Name","value":"destinations"}},{"kind":"Field","name":{"kind":"Name","value":"enabled"}}]}}]}}]} as unknown as DocumentNode<AlertsQuery, AlertsQueryVariables>;
export const UpdateAlertDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"UpdateAlert"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"id"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"action"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"updateAlert"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"id"},"value":{"kind":"Variable","name":{"kind":"Name","value":"id"}}},{"kind":"Argument","name":{"kind":"Name","value":"action"},"value":{"kind":"Variable","name":{"kind":"Name","value":"action"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"state"}}]}}]}}]} as unknown as DocumentNode<UpdateAlertMutation, UpdateAlertMutationVariables>;
export const RetryAlertDeliveryDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"RetryAlertDelivery"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"id"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"retryAlertDelivery"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"id"},"value":{"kind":"Variable","name":{"kind":"Name","value":"id"}}}]}]}}]} as unknown as DocumentNode<RetryAlertDeliveryMutation, RetryAlertDeliveryMutationVariables>;
export const SaveAlertPolicyDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"SaveAlertPolicy"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"input"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"AlertPolicyInput"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"saveAlertPolicy"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"input"},"value":{"kind":"Variable","name":{"kind":"Name","value":"input"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}}]}}]}}]} as unknown as DocumentNode<SaveAlertPolicyMutation, SaveAlertPolicyMutationVariables>;
export const OperationTimelineDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"OperationTimeline"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"operationId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"operationTimeline"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"operationId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"operationId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"operation"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"operationId"}},{"kind":"Field","name":{"kind":"Name","value":"kind"}},{"kind":"Field","name":{"kind":"Name","value":"state"}},{"kind":"Field","name":{"kind":"Name","value":"accountRef"}},{"kind":"Field","name":{"kind":"Name","value":"amountSats"}},{"kind":"Field","name":{"kind":"Name","value":"txid"}},{"kind":"Field","name":{"kind":"Name","value":"vout"}},{"kind":"Field","name":{"kind":"Name","value":"generation"}}]}},{"kind":"Field","name":{"kind":"Name","value":"journals"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"entryKind"}},{"kind":"Field","name":{"kind":"Name","value":"ruleName"}},{"kind":"Field","name":{"kind":"Name","value":"ruleVersion"}},{"kind":"Field","name":{"kind":"Name","value":"description"}},{"kind":"Field","name":{"kind":"Name","value":"postedAt"}},{"kind":"Field","name":{"kind":"Name","value":"correlationId"}},{"kind":"Field","name":{"kind":"Name","value":"postings"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"accountCode"}},{"kind":"Field","name":{"kind":"Name","value":"direction"}},{"kind":"Field","name":{"kind":"Name","value":"amountSats"}}]}}]}},{"kind":"Field","name":{"kind":"Name","value":"events"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"seq"}},{"kind":"Field","name":{"kind":"Name","value":"eventType"}},{"kind":"Field","name":{"kind":"Name","value":"observedAt"}},{"kind":"Field","name":{"kind":"Name","value":"aggregateId"}},{"kind":"Field","name":{"kind":"Name","value":"correlationId"}},{"kind":"Field","name":{"kind":"Name","value":"payload"}}]}}]}}]}}]} as unknown as DocumentNode<OperationTimelineQuery, OperationTimelineQueryVariables>;
export const AuditLogDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"AuditLog"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"action"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"auditLog"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"action"},"value":{"kind":"Variable","name":{"kind":"Name","value":"action"}}},{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"IntValue","value":"200"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"actorEmail"}},{"kind":"Field","name":{"kind":"Name","value":"action"}},{"kind":"Field","name":{"kind":"Name","value":"resourceType"}},{"kind":"Field","name":{"kind":"Name","value":"resourceId"}},{"kind":"Field","name":{"kind":"Name","value":"changes"}},{"kind":"Field","name":{"kind":"Name","value":"ip"}},{"kind":"Field","name":{"kind":"Name","value":"insertedAt"}}]}}]}}]} as unknown as DocumentNode<AuditLogQuery, AuditLogQueryVariables>;
export const ChainOverviewDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"ChainOverview"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"chainOverview"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"checkpointHeight"}},{"kind":"Field","name":{"kind":"Name","value":"checkpointHash"}},{"kind":"Field","name":{"kind":"Name","value":"checkpointUpdatedAt"}},{"kind":"Field","name":{"kind":"Name","value":"mempoolSize"}},{"kind":"Field","name":{"kind":"Name","value":"transactionCounts"}},{"kind":"Field","name":{"kind":"Name","value":"diverged"}},{"kind":"Field","name":{"kind":"Name","value":"referenceNode"}},{"kind":"Field","name":{"kind":"Name","value":"requiredConfirmations"}},{"kind":"Field","name":{"kind":"Name","value":"tip"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"height"}},{"kind":"Field","name":{"kind":"Name","value":"hash"}},{"kind":"Field","name":{"kind":"Name","value":"blockTime"}}]}},{"kind":"Field","name":{"kind":"Name","value":"reorganizations"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"seq"}},{"kind":"Field","name":{"kind":"Name","value":"observedAt"}},{"kind":"Field","name":{"kind":"Name","value":"payload"}},{"kind":"Field","name":{"kind":"Name","value":"eventType"}},{"kind":"Field","name":{"kind":"Name","value":"schemaVersion"}},{"kind":"Field","name":{"kind":"Name","value":"aggregateType"}},{"kind":"Field","name":{"kind":"Name","value":"aggregateId"}},{"kind":"Field","name":{"kind":"Name","value":"correlationId"}},{"kind":"Field","name":{"kind":"Name","value":"causationId"}}]}},{"kind":"Field","name":{"kind":"Name","value":"staleBlocks"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"hash"}},{"kind":"Field","name":{"kind":"Name","value":"height"}},{"kind":"Field","name":{"kind":"Name","value":"disconnectedAt"}}]}}]}}]}}]} as unknown as DocumentNode<ChainOverviewQuery, ChainOverviewQueryVariables>;
export const BlocksDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Blocks"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"blocks"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"IntValue","value":"30"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"hash"}},{"kind":"Field","name":{"kind":"Name","value":"height"}},{"kind":"Field","name":{"kind":"Name","value":"txCount"}},{"kind":"Field","name":{"kind":"Name","value":"blockTime"}},{"kind":"Field","name":{"kind":"Name","value":"connectedAt"}},{"kind":"Field","name":{"kind":"Name","value":"inBestChain"}}]}}]}}]} as unknown as DocumentNode<BlocksQuery, BlocksQueryVariables>;
export const DomainEventsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"DomainEvents"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"types"}},"type":{"kind":"ListType","type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"events"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"types"},"value":{"kind":"Variable","name":{"kind":"Name","value":"types"}}},{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"IntValue","value":"100"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"seq"}},{"kind":"Field","name":{"kind":"Name","value":"eventType"}},{"kind":"Field","name":{"kind":"Name","value":"schemaVersion"}},{"kind":"Field","name":{"kind":"Name","value":"aggregateType"}},{"kind":"Field","name":{"kind":"Name","value":"aggregateId"}},{"kind":"Field","name":{"kind":"Name","value":"correlationId"}},{"kind":"Field","name":{"kind":"Name","value":"causationId"}},{"kind":"Field","name":{"kind":"Name","value":"observedAt"}},{"kind":"Field","name":{"kind":"Name","value":"payload"}}]}}]}}]} as unknown as DocumentNode<DomainEventsQuery, DomainEventsQueryVariables>;
export const ConfigResourceDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"ConfigResource"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"kind"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"name"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"configResource"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"kind"},"value":{"kind":"Variable","name":{"kind":"Name","value":"kind"}}},{"kind":"Argument","name":{"kind":"Name","value":"name"},"value":{"kind":"Variable","name":{"kind":"Name","value":"name"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"kind"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"desiredRevision"}},{"kind":"Field","name":{"kind":"Name","value":"appliedRevision"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"statusMessage"}},{"kind":"Field","name":{"kind":"Name","value":"observed"}},{"kind":"Field","name":{"kind":"Name","value":"document"}},{"kind":"Field","name":{"kind":"Name","value":"updatedAt"}},{"kind":"Field","name":{"kind":"Name","value":"revisions"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"revision"}},{"kind":"Field","name":{"kind":"Name","value":"yaml"}},{"kind":"Field","name":{"kind":"Name","value":"spec"}},{"kind":"Field","name":{"kind":"Name","value":"authorEmail"}},{"kind":"Field","name":{"kind":"Name","value":"message"}},{"kind":"Field","name":{"kind":"Name","value":"insertedAt"}}]}}]}}]}}]} as unknown as DocumentNode<ConfigResourceQuery, ConfigResourceQueryVariables>;
export const ValidateConfigDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"ValidateConfig"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"yaml"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"validateConfig"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"yaml"},"value":{"kind":"Variable","name":{"kind":"Name","value":"yaml"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"valid"}},{"kind":"Field","name":{"kind":"Name","value":"document"}},{"kind":"Field","name":{"kind":"Name","value":"canonicalYaml"}},{"kind":"Field","name":{"kind":"Name","value":"errors"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"path"}},{"kind":"Field","name":{"kind":"Name","value":"message"}},{"kind":"Field","name":{"kind":"Name","value":"line"}},{"kind":"Field","name":{"kind":"Name","value":"column"}}]}}]}}]}}]} as unknown as DocumentNode<ValidateConfigMutation, ValidateConfigMutationVariables>;
export const PlanConfigDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"PlanConfig"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"document"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"JSON"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"planConfig"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"document"},"value":{"kind":"Variable","name":{"kind":"Name","value":"document"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"action"}},{"kind":"Field","name":{"kind":"Name","value":"kind"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"currentRevision"}},{"kind":"Field","name":{"kind":"Name","value":"impact"}},{"kind":"Field","name":{"kind":"Name","value":"canonicalYaml"}},{"kind":"Field","name":{"kind":"Name","value":"currentYaml"}},{"kind":"Field","name":{"kind":"Name","value":"changes"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"op"}},{"kind":"Field","name":{"kind":"Name","value":"path"}},{"kind":"Field","name":{"kind":"Name","value":"old"}},{"kind":"Field","name":{"kind":"Name","value":"new"}}]}}]}}]}}]} as unknown as DocumentNode<PlanConfigMutation, PlanConfigMutationVariables>;
export const ApplyConfigDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"ApplyConfig"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"document"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"JSON"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"expectedRevision"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"Int"}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"message"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"applyConfig"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"document"},"value":{"kind":"Variable","name":{"kind":"Name","value":"document"}}},{"kind":"Argument","name":{"kind":"Name","value":"expectedRevision"},"value":{"kind":"Variable","name":{"kind":"Name","value":"expectedRevision"}}},{"kind":"Argument","name":{"kind":"Name","value":"message"},"value":{"kind":"Variable","name":{"kind":"Name","value":"message"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"changed"}},{"kind":"Field","name":{"kind":"Name","value":"resource"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"kind"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"desiredRevision"}},{"kind":"Field","name":{"kind":"Name","value":"appliedRevision"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"statusMessage"}}]}}]}}]}}]} as unknown as DocumentNode<ApplyConfigMutation, ApplyConfigMutationVariables>;
export const ReapplyConfigDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"ReapplyConfig"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"kind"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"name"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"revision"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"Int"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"reapplyConfig"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"kind"},"value":{"kind":"Variable","name":{"kind":"Name","value":"kind"}}},{"kind":"Argument","name":{"kind":"Name","value":"name"},"value":{"kind":"Variable","name":{"kind":"Name","value":"name"}}},{"kind":"Argument","name":{"kind":"Name","value":"revision"},"value":{"kind":"Variable","name":{"kind":"Name","value":"revision"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"changed"}}]}}]}}]} as unknown as DocumentNode<ReapplyConfigMutation, ReapplyConfigMutationVariables>;
export const ConfigResourcesDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"ConfigResources"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"kind"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"configResources"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"kind"},"value":{"kind":"Variable","name":{"kind":"Name","value":"kind"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"kind"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"environmentRef"}},{"kind":"Field","name":{"kind":"Name","value":"desiredRevision"}},{"kind":"Field","name":{"kind":"Name","value":"appliedRevision"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"statusMessage"}},{"kind":"Field","name":{"kind":"Name","value":"updatedAt"}}]}}]}}]} as unknown as DocumentNode<ConfigResourcesQuery, ConfigResourcesQueryVariables>;
export const EnvironmentsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Environments"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"environments"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"slug"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"kind"}},{"kind":"Field","name":{"kind":"Name","value":"network"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"requiredConfirmations"}},{"kind":"Field","name":{"kind":"Name","value":"settings"}},{"kind":"Field","name":{"kind":"Name","value":"insertedAt"}}]}}]}}]} as unknown as DocumentNode<EnvironmentsQuery, EnvironmentsQueryVariables>;
export const CreateEnvironmentDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"CreateEnvironment"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"slug"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"name"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"requiredConfirmations"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"Int"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"createEnvironment"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"slug"},"value":{"kind":"Variable","name":{"kind":"Name","value":"slug"}}},{"kind":"Argument","name":{"kind":"Name","value":"name"},"value":{"kind":"Variable","name":{"kind":"Name","value":"name"}}},{"kind":"Argument","name":{"kind":"Name","value":"requiredConfirmations"},"value":{"kind":"Variable","name":{"kind":"Name","value":"requiredConfirmations"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}}]}}]}}]} as unknown as DocumentNode<CreateEnvironmentMutation, CreateEnvironmentMutationVariables>;
export const ExperimentRunDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"ExperimentRun"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"id"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"experimentRun"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"id"},"value":{"kind":"Variable","name":{"kind":"Name","value":"id"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"scenarioName"}},{"kind":"Field","name":{"kind":"Name","value":"scenarioVersion"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"statusReason"}},{"kind":"Field","name":{"kind":"Name","value":"cleanupStatus"}},{"kind":"Field","name":{"kind":"Name","value":"seed"}},{"kind":"Field","name":{"kind":"Name","value":"startedAt"}},{"kind":"Field","name":{"kind":"Name","value":"finishedAt"}},{"kind":"Field","name":{"kind":"Name","value":"insertedAt"}},{"kind":"Field","name":{"kind":"Name","value":"report"}},{"kind":"Field","name":{"kind":"Name","value":"steps"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"position"}},{"kind":"Field","name":{"kind":"Name","value":"stepKey"}},{"kind":"Field","name":{"kind":"Name","value":"phase"}},{"kind":"Field","name":{"kind":"Name","value":"action"}},{"kind":"Field","name":{"kind":"Name","value":"params"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"attempts"}},{"kind":"Field","name":{"kind":"Name","value":"maxAttempts"}},{"kind":"Field","name":{"kind":"Name","value":"timeoutMs"}},{"kind":"Field","name":{"kind":"Name","value":"checkpoint"}},{"kind":"Field","name":{"kind":"Name","value":"result"}},{"kind":"Field","name":{"kind":"Name","value":"failureReason"}},{"kind":"Field","name":{"kind":"Name","value":"startedAt"}},{"kind":"Field","name":{"kind":"Name","value":"finishedAt"}}]}},{"kind":"Field","name":{"kind":"Name","value":"assertions"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"position"}},{"kind":"Field","name":{"kind":"Name","value":"type"}},{"kind":"Field","name":{"kind":"Name","value":"params"}},{"kind":"Field","name":{"kind":"Name","value":"outcome"}},{"kind":"Field","name":{"kind":"Name","value":"expected"}},{"kind":"Field","name":{"kind":"Name","value":"actual"}},{"kind":"Field","name":{"kind":"Name","value":"message"}},{"kind":"Field","name":{"kind":"Name","value":"attempts"}}]}}]}}]}}]} as unknown as DocumentNode<ExperimentRunQuery, ExperimentRunQueryVariables>;
export const AbortExperimentDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"AbortExperiment"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"id"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"abortExperiment"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"id"},"value":{"kind":"Variable","name":{"kind":"Name","value":"id"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"status"}}]}}]}}]} as unknown as DocumentNode<AbortExperimentMutation, AbortExperimentMutationVariables>;
export const ExperimentRunsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"ExperimentRuns"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"scenarios"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"version"}},{"kind":"Field","name":{"kind":"Name","value":"title"}},{"kind":"Field","name":{"kind":"Name","value":"description"}},{"kind":"Field","name":{"kind":"Name","value":"guarantee"}},{"kind":"Field","name":{"kind":"Name","value":"requiredCapabilities"}},{"kind":"Field","name":{"kind":"Name","value":"versions"}}]}},{"kind":"Field","name":{"kind":"Name","value":"runtimeCapabilities"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}]},{"kind":"Field","name":{"kind":"Name","value":"experimentActions"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"idempotency"}},{"kind":"Field","name":{"kind":"Name","value":"capabilities"}}]}},{"kind":"Field","name":{"kind":"Name","value":"experimentRuns"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"IntValue","value":"50"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"scenarioName"}},{"kind":"Field","name":{"kind":"Name","value":"scenarioVersion"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"statusReason"}},{"kind":"Field","name":{"kind":"Name","value":"seed"}},{"kind":"Field","name":{"kind":"Name","value":"startedAt"}},{"kind":"Field","name":{"kind":"Name","value":"finishedAt"}},{"kind":"Field","name":{"kind":"Name","value":"insertedAt"}}]}}]}}]} as unknown as DocumentNode<ExperimentRunsQuery, ExperimentRunsQueryVariables>;
export const StartExperimentDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"StartExperiment"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"scenarioId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"seed"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"Int"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"startExperiment"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"scenarioId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"scenarioId"}}},{"kind":"Argument","name":{"kind":"Name","value":"seed"},"value":{"kind":"Variable","name":{"kind":"Name","value":"seed"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}}]}}]}}]} as unknown as DocumentNode<StartExperimentMutation, StartExperimentMutationVariables>;
export const IntegrationsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Integrations"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"integrations"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"kind"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"enabled"}},{"kind":"Field","name":{"kind":"Name","value":"config"}},{"kind":"Field","name":{"kind":"Name","value":"secretRef"}},{"kind":"Field","name":{"kind":"Name","value":"health"}},{"kind":"Field","name":{"kind":"Name","value":"capabilities"}},{"kind":"Field","name":{"kind":"Name","value":"checkpoint"}},{"kind":"Field","name":{"kind":"Name","value":"lastSyncAt"}},{"kind":"Field","name":{"kind":"Name","value":"lastError"}},{"kind":"Field","name":{"kind":"Name","value":"lockVersion"}},{"kind":"Field","name":{"kind":"Name","value":"updatedAt"}},{"kind":"Field","name":{"kind":"Name","value":"errors"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"message"}},{"kind":"Field","name":{"kind":"Name","value":"occurredAt"}}]}}]}},{"kind":"Field","name":{"kind":"Name","value":"secretNames"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}]},{"kind":"Field","name":{"kind":"Name","value":"integrationKinds"}}]}}]} as unknown as DocumentNode<IntegrationsQuery, IntegrationsQueryVariables>;
export const TestIntegrationDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"TestIntegration"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"id"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"testIntegration"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"id"},"value":{"kind":"Variable","name":{"kind":"Name","value":"id"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"ok"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"details"}},{"kind":"Field","name":{"kind":"Name","value":"error"}}]}}]}}]} as unknown as DocumentNode<TestIntegrationMutation, TestIntegrationMutationVariables>;
export const SaveIntegrationDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"SaveIntegration"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"input"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"IntegrationInput"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"saveIntegration"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"input"},"value":{"kind":"Variable","name":{"kind":"Name","value":"input"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}}]}}]}}]} as unknown as DocumentNode<SaveIntegrationMutation, SaveIntegrationMutationVariables>;
export const DeleteIntegrationDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"DeleteIntegration"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"id"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"deleteIntegration"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"id"},"value":{"kind":"Variable","name":{"kind":"Name","value":"id"}}}]}]}}]} as unknown as DocumentNode<DeleteIntegrationMutation, DeleteIntegrationMutationVariables>;
export const PutSecretDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"PutSecret"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"name"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"value"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"putSecret"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"name"},"value":{"kind":"Variable","name":{"kind":"Name","value":"name"}}},{"kind":"Argument","name":{"kind":"Name","value":"value"},"value":{"kind":"Variable","name":{"kind":"Name","value":"value"}}}]}]}}]} as unknown as DocumentNode<PutSecretMutation, PutSecretMutationVariables>;
export const JobsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Jobs"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"state"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"jobStats"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"queue"}},{"kind":"Field","name":{"kind":"Name","value":"state"}},{"kind":"Field","name":{"kind":"Name","value":"count"}}]}},{"kind":"Field","name":{"kind":"Name","value":"eventConsumers"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"consumer"}},{"kind":"Field","name":{"kind":"Name","value":"lastSeq"}},{"kind":"Field","name":{"kind":"Name","value":"lag"}},{"kind":"Field","name":{"kind":"Name","value":"updatedAt"}}]}},{"kind":"Field","name":{"kind":"Name","value":"jobs"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"state"},"value":{"kind":"Variable","name":{"kind":"Name","value":"state"}}},{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"IntValue","value":"100"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"queue"}},{"kind":"Field","name":{"kind":"Name","value":"worker"}},{"kind":"Field","name":{"kind":"Name","value":"state"}},{"kind":"Field","name":{"kind":"Name","value":"attempt"}},{"kind":"Field","name":{"kind":"Name","value":"maxAttempts"}},{"kind":"Field","name":{"kind":"Name","value":"errors"}},{"kind":"Field","name":{"kind":"Name","value":"insertedAt"}},{"kind":"Field","name":{"kind":"Name","value":"attemptedAt"}},{"kind":"Field","name":{"kind":"Name","value":"completedAt"}}]}}]}}]} as unknown as DocumentNode<JobsQuery, JobsQueryVariables>;
export const ReplayEventsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"ReplayEvents"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"consumer"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"fromSeq"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"Int"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"replayEvents"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"consumer"},"value":{"kind":"Variable","name":{"kind":"Name","value":"consumer"}}},{"kind":"Argument","name":{"kind":"Name","value":"fromSeq"},"value":{"kind":"Variable","name":{"kind":"Name","value":"fromSeq"}}}]}]}}]} as unknown as DocumentNode<ReplayEventsMutation, ReplayEventsMutationVariables>;
export const LedgerAccountsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"LedgerAccounts"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"ledgerAccounts"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"code"}},{"kind":"Field","name":{"kind":"Name","value":"type"}},{"kind":"Field","name":{"kind":"Name","value":"normalBalance"}},{"kind":"Field","name":{"kind":"Name","value":"restricted"}},{"kind":"Field","name":{"kind":"Name","value":"ownerRef"}},{"kind":"Field","name":{"kind":"Name","value":"balanceSats"}},{"kind":"Field","name":{"kind":"Name","value":"debitTotal"}},{"kind":"Field","name":{"kind":"Name","value":"creditTotal"}}]}},{"kind":"Field","name":{"kind":"Name","value":"ledgerInvariants"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"ok"}},{"kind":"Field","name":{"kind":"Name","value":"balanced"}},{"kind":"Field","name":{"kind":"Name","value":"totalDebits"}},{"kind":"Field","name":{"kind":"Name","value":"totalCredits"}},{"kind":"Field","name":{"kind":"Name","value":"unbalancedJournals"}},{"kind":"Field","name":{"kind":"Name","value":"projectionDrift"}},{"kind":"Field","name":{"kind":"Name","value":"negativeRestricted"}},{"kind":"Field","name":{"kind":"Name","value":"duplicateCredits"}}]}},{"kind":"Field","name":{"kind":"Name","value":"financialRules"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"version"}},{"kind":"Field","name":{"kind":"Name","value":"current"}}]}},{"kind":"Field","name":{"kind":"Name","value":"customerBalances"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"accountRef"}},{"kind":"Field","name":{"kind":"Name","value":"availableSats"}},{"kind":"Field","name":{"kind":"Name","value":"pendingSats"}},{"kind":"Field","name":{"kind":"Name","value":"reservedSats"}}]}}]}}]} as unknown as DocumentNode<LedgerAccountsQuery, LedgerAccountsQueryVariables>;
export const JournalsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Journals"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"journals"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"IntValue","value":"100"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"operationId"}},{"kind":"Field","name":{"kind":"Name","value":"entryKind"}},{"kind":"Field","name":{"kind":"Name","value":"ruleName"}},{"kind":"Field","name":{"kind":"Name","value":"ruleVersion"}},{"kind":"Field","name":{"kind":"Name","value":"description"}},{"kind":"Field","name":{"kind":"Name","value":"reversesJournalId"}},{"kind":"Field","name":{"kind":"Name","value":"postedAt"}},{"kind":"Field","name":{"kind":"Name","value":"metadata"}},{"kind":"Field","name":{"kind":"Name","value":"postings"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"accountCode"}},{"kind":"Field","name":{"kind":"Name","value":"direction"}},{"kind":"Field","name":{"kind":"Name","value":"amountSats"}}]}}]}}]}}]} as unknown as DocumentNode<JournalsQuery, JournalsQueryVariables>;
export const LedgerOperationsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"LedgerOperations"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"ledgerOperations"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"IntValue","value":"200"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"operationId"}},{"kind":"Field","name":{"kind":"Name","value":"kind"}},{"kind":"Field","name":{"kind":"Name","value":"state"}},{"kind":"Field","name":{"kind":"Name","value":"accountRef"}},{"kind":"Field","name":{"kind":"Name","value":"amountSats"}},{"kind":"Field","name":{"kind":"Name","value":"feeSats"}},{"kind":"Field","name":{"kind":"Name","value":"txid"}},{"kind":"Field","name":{"kind":"Name","value":"generation"}},{"kind":"Field","name":{"kind":"Name","value":"updatedAt"}}]}}]}}]} as unknown as DocumentNode<LedgerOperationsQuery, LedgerOperationsQueryVariables>;
export const CompensateJournalDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"CompensateJournal"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"journalId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"reason"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"compensateJournal"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"journalId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"journalId"}}},{"kind":"Argument","name":{"kind":"Name","value":"reason"},"value":{"kind":"Variable","name":{"kind":"Name","value":"reason"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"status"}}]}}]}}]} as unknown as DocumentNode<CompensateJournalMutation, CompensateJournalMutationVariables>;
export const RequestWithdrawalDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"RequestWithdrawal"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"accountRef"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"amountSats"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"Sats"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"idempotencyKey"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"requestWithdrawal"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"accountRef"},"value":{"kind":"Variable","name":{"kind":"Name","value":"accountRef"}}},{"kind":"Argument","name":{"kind":"Name","value":"amountSats"},"value":{"kind":"Variable","name":{"kind":"Name","value":"amountSats"}}},{"kind":"Argument","name":{"kind":"Name","value":"idempotencyKey"},"value":{"kind":"Variable","name":{"kind":"Name","value":"idempotencyKey"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"status"}}]}}]}}]} as unknown as DocumentNode<RequestWithdrawalMutation, RequestWithdrawalMutationVariables>;
export const InternalTransferDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"InternalTransfer"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"fromRef"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"toRef"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"amountSats"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"Sats"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"idempotencyKey"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"internalTransfer"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"fromRef"},"value":{"kind":"Variable","name":{"kind":"Name","value":"fromRef"}}},{"kind":"Argument","name":{"kind":"Name","value":"toRef"},"value":{"kind":"Variable","name":{"kind":"Name","value":"toRef"}}},{"kind":"Argument","name":{"kind":"Name","value":"amountSats"},"value":{"kind":"Variable","name":{"kind":"Name","value":"amountSats"}}},{"kind":"Argument","name":{"kind":"Name","value":"idempotencyKey"},"value":{"kind":"Variable","name":{"kind":"Name","value":"idempotencyKey"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"status"}}]}}]}}]} as unknown as DocumentNode<InternalTransferMutation, InternalTransferMutationVariables>;
export const NodesDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Nodes"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"nodes"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"isReference"}},{"kind":"Field","name":{"kind":"Name","value":"integration"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"config"}},{"kind":"Field","name":{"kind":"Name","value":"lastError"}},{"kind":"Field","name":{"kind":"Name","value":"lastSyncAt"}}]}},{"kind":"Field","name":{"kind":"Name","value":"latest"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"reachable"}},{"kind":"Field","name":{"kind":"Name","value":"chain"}},{"kind":"Field","name":{"kind":"Name","value":"height"}},{"kind":"Field","name":{"kind":"Name","value":"bestHash"}},{"kind":"Field","name":{"kind":"Name","value":"chainwork"}},{"kind":"Field","name":{"kind":"Name","value":"peers"}},{"kind":"Field","name":{"kind":"Name","value":"mempoolSize"}},{"kind":"Field","name":{"kind":"Name","value":"rpcLatencyMs"}},{"kind":"Field","name":{"kind":"Name","value":"observedAt"}},{"kind":"Field","name":{"kind":"Name","value":"error"}},{"kind":"Field","name":{"kind":"Name","value":"initialBlockDownload"}}]}},{"kind":"Field","name":{"kind":"Name","value":"history"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"IntValue","value":"60"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"observedAt"}},{"kind":"Field","name":{"kind":"Name","value":"height"}},{"kind":"Field","name":{"kind":"Name","value":"rpcLatencyMs"}},{"kind":"Field","name":{"kind":"Name","value":"reachable"}}]}},{"kind":"Field","name":{"kind":"Name","value":"downtime"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"eventType"}},{"kind":"Field","name":{"kind":"Name","value":"observedAt"}},{"kind":"Field","name":{"kind":"Name","value":"payload"}}]}},{"kind":"Field","name":{"kind":"Name","value":"zmq"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"lastSequence"}},{"kind":"Field","name":{"kind":"Name","value":"gapsTotal"}},{"kind":"Field","name":{"kind":"Name","value":"duplicatesTotal"}},{"kind":"Field","name":{"kind":"Name","value":"updatedAt"}}]}}]}},{"kind":"Field","name":{"kind":"Name","value":"chainOverview"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"diverged"}},{"kind":"Field","name":{"kind":"Name","value":"referenceNode"}},{"kind":"Field","name":{"kind":"Name","value":"tip"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"height"}},{"kind":"Field","name":{"kind":"Name","value":"hash"}}]}}]}}]}}]} as unknown as DocumentNode<NodesQuery, NodesQueryVariables>;
export const SyncChainDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"SyncChain"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"syncChain"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}]}]}}]} as unknown as DocumentNode<SyncChainMutation, SyncChainMutationVariables>;
export const DashboardsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Dashboards"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"workspace"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"dashboards"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"workspace"},"value":{"kind":"Variable","name":{"kind":"Name","value":"workspace"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"title"}},{"kind":"Field","name":{"kind":"Name","value":"workspace"}},{"kind":"Field","name":{"kind":"Name","value":"spec"}},{"kind":"Field","name":{"kind":"Name","value":"isDefault"}},{"kind":"Field","name":{"kind":"Name","value":"shared"}},{"kind":"Field","name":{"kind":"Name","value":"lockVersion"}}]}},{"kind":"Field","name":{"kind":"Name","value":"widgetTypes"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"type"}},{"kind":"Field","name":{"kind":"Name","value":"minWidth"}},{"kind":"Field","name":{"kind":"Name","value":"minHeight"}},{"kind":"Field","name":{"kind":"Name","value":"permission"}},{"kind":"Field","name":{"kind":"Name","value":"workspaces"}},{"kind":"Field","name":{"kind":"Name","value":"refresh"}}]}}]}}]} as unknown as DocumentNode<DashboardsQuery, DashboardsQueryVariables>;
export const SaveDashboardDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"SaveDashboard"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"name"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"spec"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"JSON"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"lockVersion"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"Int"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"saveDashboard"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"name"},"value":{"kind":"Variable","name":{"kind":"Name","value":"name"}}},{"kind":"Argument","name":{"kind":"Name","value":"spec"},"value":{"kind":"Variable","name":{"kind":"Name","value":"spec"}}},{"kind":"Argument","name":{"kind":"Name","value":"lockVersion"},"value":{"kind":"Variable","name":{"kind":"Name","value":"lockVersion"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"lockVersion"}}]}}]}}]} as unknown as DocumentNode<SaveDashboardMutation, SaveDashboardMutationVariables>;
export const RestoreDashboardDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"RestoreDashboard"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"workspace"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"restoreDefaultDashboard"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"workspace"},"value":{"kind":"Variable","name":{"kind":"Name","value":"workspace"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}}]}}]}}]} as unknown as DocumentNode<RestoreDashboardMutation, RestoreDashboardMutationVariables>;
export const OverviewDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Overview"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"overview"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"confirmedSats"}},{"kind":"Field","name":{"kind":"Name","value":"pendingSats"}},{"kind":"Field","name":{"kind":"Name","value":"utxoCount"}},{"kind":"Field","name":{"kind":"Name","value":"tipHeight"}},{"kind":"Field","name":{"kind":"Name","value":"tipHash"}},{"kind":"Field","name":{"kind":"Name","value":"tipTime"}},{"kind":"Field","name":{"kind":"Name","value":"mempoolSize"}},{"kind":"Field","name":{"kind":"Name","value":"openDiscrepancies"}},{"kind":"Field","name":{"kind":"Name","value":"firingAlerts"}},{"kind":"Field","name":{"kind":"Name","value":"ingestionLagBlocks"}},{"kind":"Field","name":{"kind":"Name","value":"ingestionLatencyMs"}},{"kind":"Field","name":{"kind":"Name","value":"lastReconciliation"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"completeness"}},{"kind":"Field","name":{"kind":"Name","value":"summary"}},{"kind":"Field","name":{"kind":"Name","value":"finishedAt"}}]}},{"kind":"Field","name":{"kind":"Name","value":"activeExperiments"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"scenarioName"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"startedAt"}}]}},{"kind":"Field","name":{"kind":"Name","value":"recentExperiments"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"scenarioName"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"finishedAt"}},{"kind":"Field","name":{"kind":"Name","value":"statusReason"}}]}}]}}]}}]} as unknown as DocumentNode<OverviewQuery, OverviewQueryVariables>;
export const WidgetNodesDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"WidgetNodes"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"nodes"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"isReference"}},{"kind":"Field","name":{"kind":"Name","value":"integration"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"status"}}]}},{"kind":"Field","name":{"kind":"Name","value":"latest"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"reachable"}},{"kind":"Field","name":{"kind":"Name","value":"height"}},{"kind":"Field","name":{"kind":"Name","value":"rpcLatencyMs"}},{"kind":"Field","name":{"kind":"Name","value":"peers"}},{"kind":"Field","name":{"kind":"Name","value":"observedAt"}}]}},{"kind":"Field","name":{"kind":"Name","value":"history"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"IntValue","value":"40"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"observedAt"}},{"kind":"Field","name":{"kind":"Name","value":"rpcLatencyMs"}},{"kind":"Field","name":{"kind":"Name","value":"height"}},{"kind":"Field","name":{"kind":"Name","value":"reachable"}}]}}]}}]}}]} as unknown as DocumentNode<WidgetNodesQuery, WidgetNodesQueryVariables>;
export const WidgetTransactionsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"WidgetTransactions"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"transactions"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"first"},"value":{"kind":"IntValue","value":"8"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"nodes"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"txid"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"confirmations"}},{"kind":"Field","name":{"kind":"Name","value":"totalOutSats"}},{"kind":"Field","name":{"kind":"Name","value":"firstSeenAt"}}]}}]}}]}}]} as unknown as DocumentNode<WidgetTransactionsQuery, WidgetTransactionsQueryVariables>;
export const WidgetVolumeDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"WidgetVolume"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"transactionVolume"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"hours"},"value":{"kind":"IntValue","value":"24"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"bucket"}},{"kind":"Field","name":{"kind":"Name","value":"count"}},{"kind":"Field","name":{"kind":"Name","value":"valueSats"}}]}}]}}]} as unknown as DocumentNode<WidgetVolumeQuery, WidgetVolumeQueryVariables>;
export const WidgetReconciliationDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"WidgetReconciliation"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"reconciliationRuns"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"IntValue","value":"20"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"completeness"}},{"kind":"Field","name":{"kind":"Name","value":"summary"}},{"kind":"Field","name":{"kind":"Name","value":"insertedAt"}},{"kind":"Field","name":{"kind":"Name","value":"finishedAt"}}]}}]}}]} as unknown as DocumentNode<WidgetReconciliationQuery, WidgetReconciliationQueryVariables>;
export const WidgetJobsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"WidgetJobs"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"jobStats"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"queue"}},{"kind":"Field","name":{"kind":"Name","value":"state"}},{"kind":"Field","name":{"kind":"Name","value":"count"}}]}}]}}]} as unknown as DocumentNode<WidgetJobsQuery, WidgetJobsQueryVariables>;
export const WidgetReorgsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"WidgetReorgs"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"chainOverview"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"reorganizations"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"observedAt"}},{"kind":"Field","name":{"kind":"Name","value":"payload"}}]}}]}}]}}]} as unknown as DocumentNode<WidgetReorgsQuery, WidgetReorgsQueryVariables>;
export const DiscrepancyDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Discrepancy"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"id"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"discrepancy"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"id"},"value":{"kind":"Variable","name":{"kind":"Name","value":"id"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"environmentId"}},{"kind":"Field","name":{"kind":"Name","value":"kind"}},{"kind":"Field","name":{"kind":"Name","value":"state"}},{"kind":"Field","name":{"kind":"Name","value":"severity"}},{"kind":"Field","name":{"kind":"Name","value":"source"}},{"kind":"Field","name":{"kind":"Name","value":"matchKey"}},{"kind":"Field","name":{"kind":"Name","value":"txid"}},{"kind":"Field","name":{"kind":"Name","value":"vout"}},{"kind":"Field","name":{"kind":"Name","value":"amountSats"}},{"kind":"Field","name":{"kind":"Name","value":"reason"}},{"kind":"Field","name":{"kind":"Name","value":"evidence"}},{"kind":"Field","name":{"kind":"Name","value":"occurrences"}},{"kind":"Field","name":{"kind":"Name","value":"firstRunId"}},{"kind":"Field","name":{"kind":"Name","value":"lastRunId"}},{"kind":"Field","name":{"kind":"Name","value":"resolution"}},{"kind":"Field","name":{"kind":"Name","value":"resolvedAt"}},{"kind":"Field","name":{"kind":"Name","value":"insertedAt"}},{"kind":"Field","name":{"kind":"Name","value":"updatedAt"}},{"kind":"Field","name":{"kind":"Name","value":"suggestion"}},{"kind":"Field","name":{"kind":"Name","value":"notes"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"authorEmail"}},{"kind":"Field","name":{"kind":"Name","value":"kind"}},{"kind":"Field","name":{"kind":"Name","value":"body"}},{"kind":"Field","name":{"kind":"Name","value":"data"}},{"kind":"Field","name":{"kind":"Name","value":"insertedAt"}}]}}]}}]}}]} as unknown as DocumentNode<DiscrepancyQuery, DiscrepancyQueryVariables>;
export const TransitionDiscrepancyDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"TransitionDiscrepancy"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"id"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"state"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"note"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"transitionDiscrepancy"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"id"},"value":{"kind":"Variable","name":{"kind":"Name","value":"id"}}},{"kind":"Argument","name":{"kind":"Name","value":"state"},"value":{"kind":"Variable","name":{"kind":"Name","value":"state"}}},{"kind":"Argument","name":{"kind":"Name","value":"note"},"value":{"kind":"Variable","name":{"kind":"Name","value":"note"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"state"}}]}}]}}]} as unknown as DocumentNode<TransitionDiscrepancyMutation, TransitionDiscrepancyMutationVariables>;
export const AddDiscrepancyNoteDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"AddDiscrepancyNote"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"id"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"body"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"kind"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"data"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"JSON"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"addDiscrepancyNote"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"id"},"value":{"kind":"Variable","name":{"kind":"Name","value":"id"}}},{"kind":"Argument","name":{"kind":"Name","value":"body"},"value":{"kind":"Variable","name":{"kind":"Name","value":"body"}}},{"kind":"Argument","name":{"kind":"Name","value":"kind"},"value":{"kind":"Variable","name":{"kind":"Name","value":"kind"}}},{"kind":"Argument","name":{"kind":"Name","value":"data"},"value":{"kind":"Variable","name":{"kind":"Name","value":"data"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}}]}}]}}]} as unknown as DocumentNode<AddDiscrepancyNoteMutation, AddDiscrepancyNoteMutationVariables>;
export const ReconciliationRunsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"ReconciliationRuns"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"reconciliationRuns"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"IntValue","value":"50"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"completeness"}},{"kind":"Field","name":{"kind":"Name","value":"trigger"}},{"kind":"Field","name":{"kind":"Name","value":"policyName"}},{"kind":"Field","name":{"kind":"Name","value":"policyVersion"}},{"kind":"Field","name":{"kind":"Name","value":"summary"}},{"kind":"Field","name":{"kind":"Name","value":"referenceHeight"}},{"kind":"Field","name":{"kind":"Name","value":"startedAt"}},{"kind":"Field","name":{"kind":"Name","value":"finishedAt"}},{"kind":"Field","name":{"kind":"Name","value":"insertedAt"}}]}}]}}]} as unknown as DocumentNode<ReconciliationRunsQuery, ReconciliationRunsQueryVariables>;
export const DiscrepanciesDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Discrepancies"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"states"}},"type":{"kind":"ListType","type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"discrepancies"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"states"},"value":{"kind":"Variable","name":{"kind":"Name","value":"states"}}},{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"IntValue","value":"200"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"kind"}},{"kind":"Field","name":{"kind":"Name","value":"state"}},{"kind":"Field","name":{"kind":"Name","value":"severity"}},{"kind":"Field","name":{"kind":"Name","value":"source"}},{"kind":"Field","name":{"kind":"Name","value":"txid"}},{"kind":"Field","name":{"kind":"Name","value":"vout"}},{"kind":"Field","name":{"kind":"Name","value":"amountSats"}},{"kind":"Field","name":{"kind":"Name","value":"reason"}},{"kind":"Field","name":{"kind":"Name","value":"occurrences"}},{"kind":"Field","name":{"kind":"Name","value":"updatedAt"}}]}}]}}]} as unknown as DocumentNode<DiscrepanciesQuery, DiscrepanciesQueryVariables>;
export const RunReconciliationDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"RunReconciliation"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"runReconciliation"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"status"}}]}}]}}]} as unknown as DocumentNode<RunReconciliationMutation, RunReconciliationMutationVariables>;
export const ReconciliationRunDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"ReconciliationRun"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"id"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"state"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"reconciliationRun"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"id"},"value":{"kind":"Variable","name":{"kind":"Name","value":"id"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"completeness"}},{"kind":"Field","name":{"kind":"Name","value":"trigger"}},{"kind":"Field","name":{"kind":"Name","value":"policyName"}},{"kind":"Field","name":{"kind":"Name","value":"policyVersion"}},{"kind":"Field","name":{"kind":"Name","value":"policy"}},{"kind":"Field","name":{"kind":"Name","value":"referenceHeight"}},{"kind":"Field","name":{"kind":"Name","value":"referenceHash"}},{"kind":"Field","name":{"kind":"Name","value":"sources"}},{"kind":"Field","name":{"kind":"Name","value":"summary"}},{"kind":"Field","name":{"kind":"Name","value":"error"}},{"kind":"Field","name":{"kind":"Name","value":"startedAt"}},{"kind":"Field","name":{"kind":"Name","value":"finishedAt"}},{"kind":"Field","name":{"kind":"Name","value":"items"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"state"},"value":{"kind":"Variable","name":{"kind":"Name","value":"state"}}},{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"IntValue","value":"1000"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"matchKey"}},{"kind":"Field","name":{"kind":"Name","value":"state"}},{"kind":"Field","name":{"kind":"Name","value":"discrepancyKind"}},{"kind":"Field","name":{"kind":"Name","value":"reason"}},{"kind":"Field","name":{"kind":"Name","value":"records"}},{"kind":"Field","name":{"kind":"Name","value":"amountSats"}},{"kind":"Field","name":{"kind":"Name","value":"txid"}},{"kind":"Field","name":{"kind":"Name","value":"vout"}}]}}]}}]}}]} as unknown as DocumentNode<ReconciliationRunQuery, ReconciliationRunQueryVariables>;
export const UsersDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Users"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"users"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"email"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"role"}},{"kind":"Field","name":{"kind":"Name","value":"disabledAt"}},{"kind":"Field","name":{"kind":"Name","value":"insertedAt"}}]}}]}}]} as unknown as DocumentNode<UsersQuery, UsersQueryVariables>;
export const CreateUserDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"CreateUser"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"email"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"name"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"role"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"password"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"createUser"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"email"},"value":{"kind":"Variable","name":{"kind":"Name","value":"email"}}},{"kind":"Argument","name":{"kind":"Name","value":"name"},"value":{"kind":"Variable","name":{"kind":"Name","value":"name"}}},{"kind":"Argument","name":{"kind":"Name","value":"role"},"value":{"kind":"Variable","name":{"kind":"Name","value":"role"}}},{"kind":"Argument","name":{"kind":"Name","value":"password"},"value":{"kind":"Variable","name":{"kind":"Name","value":"password"}}},{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}}]}}]}}]} as unknown as DocumentNode<CreateUserMutation, CreateUserMutationVariables>;
export const UpdateUserDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"UpdateUser"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"id"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"role"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"disabled"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"Boolean"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"updateUser"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"id"},"value":{"kind":"Variable","name":{"kind":"Name","value":"id"}}},{"kind":"Argument","name":{"kind":"Name","value":"role"},"value":{"kind":"Variable","name":{"kind":"Name","value":"role"}}},{"kind":"Argument","name":{"kind":"Name","value":"disabled"},"value":{"kind":"Variable","name":{"kind":"Name","value":"disabled"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}}]}}]}}]} as unknown as DocumentNode<UpdateUserMutation, UpdateUserMutationVariables>;
export const UpdateLocaleDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"UpdateLocale"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"locale"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"updateLocale"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"locale"},"value":{"kind":"Variable","name":{"kind":"Name","value":"locale"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"locale"}}]}}]}}]} as unknown as DocumentNode<UpdateLocaleMutation, UpdateLocaleMutationVariables>;
export const TransactionDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Transaction"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"txid"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"transaction"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"txid"},"value":{"kind":"Variable","name":{"kind":"Name","value":"txid"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"txid"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"blockHash"}},{"kind":"Field","name":{"kind":"Name","value":"blockHeight"}},{"kind":"Field","name":{"kind":"Name","value":"confirmations"}},{"kind":"Field","name":{"kind":"Name","value":"feeSats"}},{"kind":"Field","name":{"kind":"Name","value":"vsize"}},{"kind":"Field","name":{"kind":"Name","value":"isCoinbase"}},{"kind":"Field","name":{"kind":"Name","value":"replacedByTxid"}},{"kind":"Field","name":{"kind":"Name","value":"conflictsWith"}},{"kind":"Field","name":{"kind":"Name","value":"firstSeenAt"}},{"kind":"Field","name":{"kind":"Name","value":"statusChangedAt"}},{"kind":"Field","name":{"kind":"Name","value":"reconciliationStatus"}},{"kind":"Field","name":{"kind":"Name","value":"outputs"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"vout"}},{"kind":"Field","name":{"kind":"Name","value":"valueSats"}},{"kind":"Field","name":{"kind":"Name","value":"address"}},{"kind":"Field","name":{"kind":"Name","value":"scriptType"}},{"kind":"Field","name":{"kind":"Name","value":"spentByTxid"}},{"kind":"Field","name":{"kind":"Name","value":"watched"}}]}},{"kind":"Field","name":{"kind":"Name","value":"inputs"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"vin"}},{"kind":"Field","name":{"kind":"Name","value":"prevTxid"}},{"kind":"Field","name":{"kind":"Name","value":"prevVout"}},{"kind":"Field","name":{"kind":"Name","value":"valueSats"}},{"kind":"Field","name":{"kind":"Name","value":"address"}},{"kind":"Field","name":{"kind":"Name","value":"watched"}}]}},{"kind":"Field","name":{"kind":"Name","value":"statusHistory"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"fromStatus"}},{"kind":"Field","name":{"kind":"Name","value":"toStatus"}},{"kind":"Field","name":{"kind":"Name","value":"blockHash"}},{"kind":"Field","name":{"kind":"Name","value":"blockHeight"}},{"kind":"Field","name":{"kind":"Name","value":"reason"}},{"kind":"Field","name":{"kind":"Name","value":"insertedAt"}}]}},{"kind":"Field","name":{"kind":"Name","value":"events"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"seq"}},{"kind":"Field","name":{"kind":"Name","value":"eventType"}},{"kind":"Field","name":{"kind":"Name","value":"observedAt"}},{"kind":"Field","name":{"kind":"Name","value":"correlationId"}}]}},{"kind":"Field","name":{"kind":"Name","value":"operations"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"operationId"}},{"kind":"Field","name":{"kind":"Name","value":"kind"}},{"kind":"Field","name":{"kind":"Name","value":"state"}},{"kind":"Field","name":{"kind":"Name","value":"accountRef"}},{"kind":"Field","name":{"kind":"Name","value":"amountSats"}},{"kind":"Field","name":{"kind":"Name","value":"generation"}}]}}]}}]}}]} as unknown as DocumentNode<TransactionQuery, TransactionQueryVariables>;
export const TransactionsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Transactions"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"filter"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"TransactionFilter"}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"after"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"transactions"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"filter"},"value":{"kind":"Variable","name":{"kind":"Name","value":"filter"}}},{"kind":"Argument","name":{"kind":"Name","value":"first"},"value":{"kind":"IntValue","value":"30"}},{"kind":"Argument","name":{"kind":"Name","value":"after"},"value":{"kind":"Variable","name":{"kind":"Name","value":"after"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"nodes"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"txid"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"blockHeight"}},{"kind":"Field","name":{"kind":"Name","value":"confirmations"}},{"kind":"Field","name":{"kind":"Name","value":"feeSats"}},{"kind":"Field","name":{"kind":"Name","value":"totalOutSats"}},{"kind":"Field","name":{"kind":"Name","value":"firstSeenAt"}},{"kind":"Field","name":{"kind":"Name","value":"isCoinbase"}}]}},{"kind":"Field","name":{"kind":"Name","value":"pageInfo"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"endCursor"}},{"kind":"Field","name":{"kind":"Name","value":"hasNextPage"}}]}}]}}]}}]} as unknown as DocumentNode<TransactionsQuery, TransactionsQueryVariables>;
export const WalletsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Wallets"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"wallets"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"kind"}},{"kind":"Field","name":{"kind":"Name","value":"descriptor"}},{"kind":"Field","name":{"kind":"Name","value":"groupName"}},{"kind":"Field","name":{"kind":"Name","value":"labels"}},{"kind":"Field","name":{"kind":"Name","value":"accountRef"}},{"kind":"Field","name":{"kind":"Name","value":"derivationLimit"}},{"kind":"Field","name":{"kind":"Name","value":"addresses"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"address"}},{"kind":"Field","name":{"kind":"Name","value":"label"}},{"kind":"Field","name":{"kind":"Name","value":"derivationIndex"}}]}},{"kind":"Field","name":{"kind":"Name","value":"balance"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"confirmedSats"}},{"kind":"Field","name":{"kind":"Name","value":"pendingSats"}},{"kind":"Field","name":{"kind":"Name","value":"utxoCount"}}]}}]}}]}}]} as unknown as DocumentNode<WalletsQuery, WalletsQueryVariables>;
export const PortfolioDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"Portfolio"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"portfolio"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"walletCount"}},{"kind":"Field","name":{"kind":"Name","value":"balance"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"confirmedSats"}},{"kind":"Field","name":{"kind":"Name","value":"pendingSats"}},{"kind":"Field","name":{"kind":"Name","value":"utxoCount"}}]}},{"kind":"Field","name":{"kind":"Name","value":"utxos"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"txid"}},{"kind":"Field","name":{"kind":"Name","value":"vout"}},{"kind":"Field","name":{"kind":"Name","value":"address"}},{"kind":"Field","name":{"kind":"Name","value":"valueSats"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"blockHeight"}},{"kind":"Field","name":{"kind":"Name","value":"spentUnconfirmed"}}]}},{"kind":"Field","name":{"kind":"Name","value":"history"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"txid"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"blockHeight"}},{"kind":"Field","name":{"kind":"Name","value":"firstSeenAt"}},{"kind":"Field","name":{"kind":"Name","value":"receivedSats"}},{"kind":"Field","name":{"kind":"Name","value":"sentSats"}}]}},{"kind":"Field","name":{"kind":"Name","value":"internalTransfers"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"txid"}},{"kind":"Field","name":{"kind":"Name","value":"fromWalletId"}},{"kind":"Field","name":{"kind":"Name","value":"toWalletId"}},{"kind":"Field","name":{"kind":"Name","value":"valueSats"}}]}}]}}]}}]} as unknown as DocumentNode<PortfolioQuery, PortfolioQueryVariables>;
export const CreateWalletDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"CreateWallet"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"input"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"WalletInput"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"createWallet"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"input"},"value":{"kind":"Variable","name":{"kind":"Name","value":"input"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}}]}}]}}]} as unknown as DocumentNode<CreateWalletMutation, CreateWalletMutationVariables>;
export const DeleteWalletDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"DeleteWallet"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"id"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"deleteWallet"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"id"},"value":{"kind":"Variable","name":{"kind":"Name","value":"id"}}}]}]}}]} as unknown as DocumentNode<DeleteWalletMutation, DeleteWalletMutationVariables>;
export const TopbarAlertsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"TopbarAlerts"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"alerts"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"environmentId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"environmentId"}}},{"kind":"Argument","name":{"kind":"Name","value":"state"},"value":{"kind":"StringValue","value":"firing","block":false}},{"kind":"Argument","name":{"kind":"Name","value":"limit"},"value":{"kind":"IntValue","value":"8"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"title"}},{"kind":"Field","name":{"kind":"Name","value":"severity"}},{"kind":"Field","name":{"kind":"Name","value":"state"}},{"kind":"Field","name":{"kind":"Name","value":"lastSeenAt"}}]}}]}}]} as unknown as DocumentNode<TopbarAlertsQuery, TopbarAlertsQueryVariables>;