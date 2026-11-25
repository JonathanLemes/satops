export const FAULT_MODES = [
  "duplicate_deposit_credit",
  "missing_deposit_credit",
  "incorrect_amount",
  "delayed_settlement",
  "ignore_reorg",
  "duplicate_webhook_processing",
  "invalid_balance_projection",
  "temporary_api_outage",
  "timeout_after_success",
  "delay_response",
] as const;

export type FaultMode = (typeof FAULT_MODES)[number];

export type FaultState = Record<FaultMode, boolean> & { delayMs: number };

export function defaultFaults(): FaultState {
  const state = Object.fromEntries(FAULT_MODES.map((m) => [m, false])) as Record<FaultMode, boolean>;
  return { ...state, delayMs: 0 };
}

export function isFaultMode(value: unknown): value is FaultMode {
  return typeof value === "string" && (FAULT_MODES as readonly string[]).includes(value);
}
