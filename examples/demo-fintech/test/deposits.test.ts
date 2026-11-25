import { test } from "node:test";
import assert from "node:assert/strict";
import { planDeposit } from "../src/deposits.ts";
import { defaultFaults } from "../src/faults.ts";
import { sign, verify } from "../src/signature.ts";
import { btcToSats, satsToBtc } from "../src/money.ts";

const obs = (confirmations: number) => ({ txid: "aa", vout: 0, amountSats: 100_000, confirmations });

test("credits after the required confirmations", () => {
  const f = defaultFaults();
  assert.deepEqual(planDeposit(obs(0), null, 3, f), { status: "pending", creditCount: 0, creditedAmountSats: 0 });
  assert.equal(planDeposit(obs(2), "pending", 3, f), null);
  assert.deepEqual(planDeposit(obs(3), "pending", 3, f), { status: "credited", creditCount: 1, creditedAmountSats: 100_000 });
  assert.equal(planDeposit(obs(5), "credited", 3, f), null);
});

test("reverses on reorganization unless the fault ignores it", () => {
  assert.equal(planDeposit(obs(0), "credited", 3, defaultFaults())?.status, "reversed");
  assert.equal(planDeposit(obs(0), "credited", 3, { ...defaultFaults(), ignore_reorg: true }), null);
});

test("fault modes produce the documented incorrect behaviour", () => {
  assert.equal(planDeposit(obs(3), "pending", 3, { ...defaultFaults(), duplicate_deposit_credit: true })?.creditCount, 2);
  assert.equal(planDeposit(obs(3), "pending", 3, { ...defaultFaults(), incorrect_amount: true })?.creditedAmountSats, 99_000);
  assert.equal(planDeposit(obs(3), "pending", 3, { ...defaultFaults(), missing_deposit_credit: true }), null);
  assert.equal(planDeposit(obs(5), "pending", 3, { ...defaultFaults(), delayed_settlement: true }), null);
});

test("webhook signatures verify and expire", () => {
  const now = Date.now();
  const header = sign("secret", Math.floor(now / 1000), "{}");
  assert.ok(verify("secret", header, "{}", 300, now));
  assert.ok(!verify("other", header, "{}", 300, now));
  assert.ok(!verify("secret", header, "{}", 300, now + 3_600_000));
});

test("amounts use integer satoshis", () => {
  assert.equal(btcToSats("0.00000001"), 1);
  assert.equal(btcToSats("20999999.9769"), 2_099_999_997_690_000);
  assert.equal(btcToSats("-0.5"), -50_000_000);
  assert.equal(satsToBtc(12_345), "0.00012345");
});
