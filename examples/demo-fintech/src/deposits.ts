import type { FaultState } from "./faults.ts";

export type DepositStatus = "pending" | "credited" | "reversed";

export interface ObservedReceive {
  txid: string;
  vout: number;
  amountSats: number;
  confirmations: number;
}

export interface DepositPlan {
  status: DepositStatus;
  creditCount: number;
  creditedAmountSats: number;
}

export function planDeposit(
  observed: ObservedReceive,
  current: DepositStatus | null,
  requiredConfirmations: number,
  faults: FaultState,
): DepositPlan | null {
  const threshold = faults.delayed_settlement ? requiredConfirmations + 6 : requiredConfirmations;
  const amount = faults.incorrect_amount ? Math.max(observed.amountSats - 1_000, 1) : observed.amountSats;

  if (observed.confirmations < 0 || (observed.confirmations === 0 && current === "credited")) {
    if (current === "credited" && faults.ignore_reorg) return null;
    if (current === "credited") return { status: "reversed", creditCount: 0, creditedAmountSats: 0 };
    return null;
  }

  if (observed.confirmations >= threshold) {
    if (current === "credited") return null;
    if (faults.missing_deposit_credit) return current === null ? { status: "pending", creditCount: 0, creditedAmountSats: 0 } : null;
    return { status: "credited", creditCount: faults.duplicate_deposit_credit ? 2 : 1, creditedAmountSats: amount };
  }

  if (current === null) return { status: "pending", creditCount: 0, creditedAmountSats: 0 };
  return null;
}
