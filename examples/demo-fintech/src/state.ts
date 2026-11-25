import { pool } from "./db.ts";
import { defaultFaults, FAULT_MODES, type FaultMode, type FaultState } from "./faults.ts";

let faults: FaultState = defaultFaults();

export function getFaults(): FaultState {
  return faults;
}

export async function loadFaults() {
  const { rows } = await pool.query<{ mode: string; enabled: boolean; delay_ms: number }>("SELECT mode, enabled, delay_ms FROM faults");
  const next = defaultFaults();
  for (const row of rows) {
    if ((FAULT_MODES as readonly string[]).includes(row.mode)) next[row.mode as FaultMode] = row.enabled;
    if (row.mode === "delay_response") next.delayMs = row.delay_ms;
  }
  faults = next;
}

export async function setFault(mode: FaultMode, enabled: boolean, delayMs = 0) {
  await pool.query(
    "INSERT INTO faults (mode, enabled, delay_ms) VALUES ($1, $2, $3) ON CONFLICT (mode) DO UPDATE SET enabled = $2, delay_ms = $3",
    [mode, enabled, delayMs],
  );
  await loadFaults();
}
