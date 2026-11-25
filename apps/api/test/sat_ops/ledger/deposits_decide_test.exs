defmodule SatOps.Ledger.DepositsDecideTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias SatOps.Ledger.Deposits

  test "credits only after the confirmation policy is satisfied" do
    assert Deposits.decide(nil, "pending", 0, 3) == [:detect]
    assert Deposits.decide("detected", "confirmed", 2, 3) == []
    assert Deposits.decide("detected", "confirmed", 3, 3) == [:confirm]
    assert Deposits.decide(nil, "confirmed", 6, 3) == [:detect, :confirm]
  end

  test "confirmations are not final: a credited deposit is reversed when its block is disconnected" do
    assert Deposits.decide("credited", "confirmed", 10, 3) == []
    assert Deposits.decide("credited", "unconfirmed", 0, 3) == [:reverse]
    assert Deposits.decide("credited", "conflicted", 0, 3) == [:reverse]
    assert Deposits.decide("reversed", "confirmed", 3, 3) == [:detect, :confirm]
  end

  test "a credit re-confirmed in a different block after a reorg is reversed and re-credited explicitly" do
    assert Deposits.decide("credited", "confirmed", 4, 3, true) == [:reverse, :detect, :confirm]
    assert Deposits.decide("credited", "confirmed", 1, 3, true) == [:reverse, :detect]
  end

  test "unconfirmed deposits that disappear are cancelled, not credited" do
    assert Deposits.decide("detected", "replaced", 0, 3) == [:cancel]
    assert Deposits.decide("detected", "unknown", 0, 3) == [:cancel]
    assert Deposits.decide(nil, "conflicted", 0, 3) == []
  end

  property "the decision is idempotent: applying it once leads to a fixed point" do
    states = member_of([nil, "none", "detected", "credited", "cancelled", "reversed"])
    statuses = member_of(~w(pending confirmed unconfirmed conflicted replaced unknown))

    check all(state <- states, status <- statuses, confs <- integer(0..10), req <- integer(1..6)) do
      next_state =
        Enum.reduce(Deposits.decide(state, status, confs, req), state, fn
          :detect, _ -> "detected"
          :confirm, _ -> "credited"
          :cancel, _ -> "cancelled"
          :reverse, _ -> "reversed"
        end)

      again = Deposits.decide(next_state, status, confs, req)

      assert again == [] or (next_state in ["cancelled", "reversed"] and again in [[:detect], [:detect, :confirm]]) or
               (again == [:detect] and next_state in [nil, "none"])

      refute :confirm in again and next_state == "credited"
    end
  end
end
