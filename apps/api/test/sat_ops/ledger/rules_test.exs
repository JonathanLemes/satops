defmodule SatOps.Ledger.RulesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias SatOps.Ledger.{Draft, Rules}

  @deposit %{
    operation_id: "deposit:tx:0",
    generation: 0,
    account_ref: "cust-1",
    amount_sats: 50_000,
    txid: "tx",
    vout: 0
  }

  test "every deposit lifecycle rule produces a balanced journal" do
    for {rule, facts} <- [
          {"deposit_detected", @deposit},
          {"deposit_confirmed", Map.put(@deposit, :confirmations, 3)},
          {"deposit_cancelled", Map.put(@deposit, :reason, "dropped")},
          {"deposit_reversed", Map.put(@deposit, :available_sats, 50_000)}
        ] do
      assert {:ok, %Draft{} = d} = Rules.build(rule, facts)
      assert Draft.balanced?(d.postings)
      assert d.rule_name == rule and d.rule_version == 1
    end
  end

  test "reversal books a receivable when the customer already spent the credit" do
    {:ok, d} = Rules.build("deposit_reversed", Map.put(@deposit, :available_sats, 20_000))
    codes = Map.new(d.postings, &{&1.account_code, &1.amount_sats})
    assert codes["liabilities:customers:cust-1:available"] == 20_000
    assert codes["assets:receivables:cust-1"] == 30_000
    assert codes["assets:onchain"] == 50_000
  end

  test "invalid inputs are rejected before persistence" do
    assert {:error, :invalid_amount} = Rules.build("deposit_detected", %{@deposit | amount_sats: 0})
    assert {:error, :invalid_account_ref} = Rules.build("deposit_detected", %{@deposit | account_ref: "bad ref!"})

    assert {:error, :same_account} =
             Rules.build("internal_transfer", %{operation_id: "t", from_ref: "a", to_ref: "a", amount_sats: 1})

    assert {:error, :reason_required} = Rules.build("compensating_entry", %{operation_id: "x"})
    assert {:error, {:unknown_rule, "deposit_detected", 99}} = Rules.build("deposit_detected", @deposit, 99)
  end

  test "compensating entry mirrors every posting" do
    postings = [Draft.debit("assets:onchain", 10), Draft.credit("liabilities:customers:a:available", 10)]

    {:ok, d} =
      Rules.build("compensating_entry", %{operation_id: "op", journal_id: "j1", postings: postings, reason: "fix"})

    assert Enum.map(d.postings, & &1.direction) == ["credit", "debit"]
    assert d.reverses_journal_id == "j1"
  end

  test "fingerprint ignores posting order but not amounts" do
    a = %Draft{
      operation_id: "o",
      entry_kind: "k",
      rule_name: "r",
      rule_version: 1,
      postings: [Draft.debit("x", 1), Draft.credit("y", 1)]
    }

    b = %{a | postings: Enum.reverse(a.postings)}
    c = %{a | postings: [Draft.debit("x", 2), Draft.credit("y", 2)]}
    assert Draft.fingerprint(a) == Draft.fingerprint(b)
    refute Draft.fingerprint(a) == Draft.fingerprint(c)
  end

  property "internal transfers are always balanced and conserve value" do
    check all(
            amount <- positive_integer(),
            from <- string(:alphanumeric, min_length: 1, max_length: 10),
            to <- string(:alphanumeric, min_length: 1, max_length: 10),
            from != to
          ) do
      {:ok, d} = Rules.build("internal_transfer", %{operation_id: "t", from_ref: from, to_ref: to, amount_sats: amount})
      assert Draft.balanced?(d.postings)
      assert Enum.all?(d.postings, &(&1.amount_sats == amount))
    end
  end
end
