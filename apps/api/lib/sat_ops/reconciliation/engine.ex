defmodule SatOps.Reconciliation.Engine do
  @credited ~w(credited completed confirmed settled)
  @pending ~w(pending detected processing reserved broadcast)
  @invalid_chain ~w(unconfirmed conflicted replaced unknown)

  def run(chain_facts, sources, policy) do
    chain_by_key = Map.new(chain_facts, &{key(&1["txid"], &1["vout"]), &1})
    chain_txids = chain_facts |> Enum.map(& &1["txid"]) |> MapSet.new()

    {available, unavailable} = Enum.split_with(sources, &(&1.status == :ok))

    unavailable_items =
      for s <- unavailable do
        item(
          "source:#{s.name}",
          "discrepancy",
          "source_unavailable",
          s.name,
          "#{s.name} could not be read: #{s.error}",
          [],
          nil,
          nil,
          nil
        )
      end

    source_items =
      Enum.flat_map(available, fn s ->
        deposits = compare_deposits(s, chain_facts, chain_by_key, chain_txids, policy)
        withdrawals = compare_withdrawals(s, chain_by_key, policy)
        balances = compare_balances(s, chain_facts, policy)
        deposits ++ withdrawals ++ balances
      end)

    required_missing = Enum.filter(unavailable, & &1.required)
    items = unavailable_items ++ source_items

    %{
      items: items,
      completeness: if(required_missing == [], do: "complete", else: "incomplete"),
      summary: summarize(items)
    }
  end

  def key(txid, vout), do: "#{txid}:#{vout}"

  defp compare_deposits(source, chain_facts, chain_by_key, chain_txids, policy) do
    deposits = Enum.filter(source.records, &(&1["kind"] == "deposit"))
    by_key = Enum.group_by(deposits, &record_key/1)

    chain_items =
      for fact <- chain_facts, fact["account_ref"] do
        k = key(fact["txid"], fact["vout"])
        records = Map.get(by_key, k, [])
        classify_chain_deposit(source, fact, records, policy)
      end
      |> Enum.reject(&is_nil/1)

    orphan_items =
      for {k, records} <- by_key,
          not Map.has_key?(chain_by_key, k),
          credited = Enum.filter(records, &credited?/1),
          credited != [] do
        [r | _] = credited

        cond do
          is_nil(r["txid"]) ->
            item(
              k,
              "unmatched",
              nil,
              source.name,
              "credit without on-chain reference cannot be matched deterministically",
              records,
              r["amount_sats"],
              nil,
              nil
            )

          MapSet.member?(chain_txids, r["txid"]) ->
            item(
              k,
              "discrepancy",
              "orphan_credit",
              source.name,
              "credited output #{k} does not pay a monitored deposit address",
              records,
              r["amount_sats"],
              r["txid"],
              r["vout"]
            )

          true ->
            item(
              k,
              "discrepancy",
              "missing_transaction",
              source.name,
              "credited transaction #{r["txid"]} was never observed on the reference chain",
              records,
              r["amount_sats"],
              r["txid"],
              r["vout"]
            )
        end
      end

    chain_items ++ orphan_items
  end

  defp classify_chain_deposit(source, fact, records, policy) do
    k = key(fact["txid"], fact["vout"])
    amount = fact["amount_sats"]
    credited = Enum.filter(records, &credited?/1)
    confs = fact["confirmations"] || 0
    final = fact["status"] == "confirmed" and confs >= policy.required_confirmations
    evidence = [%{"source" => "blockchain", "fact" => fact} | Enum.map(records, &Map.put(&1, "source", source.name))]

    mk = fn state, kind, reason ->
      item(k, state, kind, source.name, reason, evidence, amount, fact["txid"], fact["vout"])
    end

    cond do
      fact["status"] in @invalid_chain and credited != [] ->
        mk.(
          "discrepancy",
          "orphan_credit",
          "#{source.name} credits #{k} but the transaction is #{fact["status"]} on the reference chain"
        )

      fact["status"] in @invalid_chain ->
        if records == [],
          do: nil,
          else: mk.("matched", nil, "transaction #{fact["status"]} and #{source.name} holds no credit")

      not final and credited != [] ->
        mk.(
          "pending",
          nil,
          "credited by #{source.name} before the confirmation policy (#{confs}/#{policy.required_confirmations})"
        )

      not final ->
        mk.("pending", nil, "awaiting confirmations (#{confs}/#{policy.required_confirmations})")

      length(credited) > 1 ->
        mk.("discrepancy", "duplicate_credit", "#{source.name} credited #{k} #{length(credited)} times")

      credited == [] and within_delay?(fact["final_at"], policy) ->
        mk.("pending", nil, "inside settlement delay of #{policy.settlement_delay_seconds}s")

      credited == [] ->
        mk.("discrepancy", "missing_credit", "confirmed deposit #{k} has no credit in #{source.name}")

      true ->
        [r] = credited

        cond do
          r["amount_sats"] != amount ->
            mk.(
              "discrepancy",
              "amount_mismatch",
              "#{source.name} credited #{r["amount_sats"]} sats; chain shows #{amount} sats"
            )

          r["account_ref"] && r["account_ref"] != fact["account_ref"] ->
            mk.("ambiguous", nil, "credited to #{r["account_ref"]} but the address belongs to #{fact["account_ref"]}")

          true ->
            mk.("matched", nil, "amount, outpoint and account agree")
        end
    end
  end

  defp compare_withdrawals(source, chain_by_key, policy) do
    chain_txs = chain_by_key |> Map.values() |> Map.new(&{&1["txid"], &1})

    for r <- source.records, r["kind"] == "withdrawal" do
      k = "withdrawal:#{r["source_record_id"]}"
      tx = r["txid"] && (Map.get(chain_txs, r["txid"]) || Map.get(policy.chain_tx_status, r["txid"]))

      mk = fn state, kind, reason ->
        item(k, state, kind, source.name, reason, [Map.put(r, "source", source.name)], r["amount_sats"], r["txid"], nil)
      end

      cond do
        r["status"] in @credited and is_nil(r["txid"]) ->
          mk.("discrepancy", "missing_withdrawal", "withdrawal marked #{r["status"]} without an on-chain transaction")

        r["status"] in @credited and (is_nil(tx) or tx["status"] != "confirmed") ->
          mk.(
            "discrepancy",
            "missing_withdrawal",
            "withdrawal marked #{r["status"]} but #{r["txid"]} is not confirmed on the reference chain"
          )

        r["status"] in @credited ->
          mk.("matched", nil, "withdrawal settled on-chain")

        r["status"] in @pending and not within_delay?(r["occurred_at"], policy) ->
          mk.("discrepancy", "settlement_delay", "withdrawal pending longer than #{policy.settlement_delay_seconds}s")

        r["status"] in @pending ->
          mk.("pending", nil, "withdrawal pending within settlement window")

        true ->
          mk.("matched", nil, "withdrawal #{r["status"]}")
      end
    end
  end

  defp compare_balances(%{balances: nil}, _chain, _policy), do: []
  defp compare_balances(%{balances: []}, _chain, _policy), do: []

  defp compare_balances(source, chain_facts, policy) do
    chain_deposits =
      chain_facts
      |> Enum.filter(
        &(&1["account_ref"] && &1["status"] == "confirmed" &&
            (&1["confirmations"] || 0) >= policy.required_confirmations)
      )
      |> Enum.group_by(& &1["account_ref"], & &1["amount_sats"])
      |> Map.new(fn {ref, amounts} -> {ref, Enum.sum(amounts)} end)

    outflows =
      source.records
      |> Enum.filter(&(&1["kind"] == "withdrawal" and &1["status"] in @credited))
      |> Enum.group_by(& &1["account_ref"], &((&1["amount_sats"] || 0) + (&1["fee_sats"] || 0)))
      |> Map.new(fn {ref, a} -> {ref, Enum.sum(a)} end)

    transfers =
      source.records
      |> Enum.filter(&(&1["kind"] in ["transfer_in", "transfer_out"] and &1["status"] in @credited))
      |> Enum.group_by(
        & &1["account_ref"],
        &if(&1["kind"] == "transfer_in", do: &1["amount_sats"], else: -&1["amount_sats"])
      )
      |> Map.new(fn {ref, a} -> {ref, Enum.sum(a)} end)

    for b <- source.balances, ref = b["account_ref"], not is_nil(ref) do
      expected = Map.get(chain_deposits, ref, 0) - Map.get(outflows, ref, 0) + Map.get(transfers, ref, 0)
      reported = (b["available_sats"] || 0) + (b["reserved_sats"] || 0)
      k = "balance:#{ref}"

      evidence = [
        %{
          "source" => source.name,
          "reported" => b,
          "expected_from_chain" => expected,
          "chain_deposits" => Map.get(chain_deposits, ref, 0),
          "outflows" => Map.get(outflows, ref, 0),
          "transfers" => Map.get(transfers, ref, 0)
        }
      ]

      if reported == expected do
        item(
          k,
          "matched",
          nil,
          source.name,
          "reported balance agrees with chain-derived expectation",
          evidence,
          reported,
          nil,
          nil
        )
      else
        item(
          k,
          "discrepancy",
          "balance_mismatch",
          source.name,
          "#{source.name} reports #{reported} sats for #{ref}; chain-derived expectation is #{expected} sats",
          evidence,
          reported - expected,
          nil,
          nil
        )
      end
    end
  end

  defp record_key(%{"txid" => nil, "source_record_id" => id}), do: "ext:#{id}"
  defp record_key(r), do: key(r["txid"], r["vout"])

  defp credited?(r), do: r["status"] in @credited

  defp within_delay?(nil, _policy), do: false

  defp within_delay?(at, policy) do
    case parse_time(at) do
      nil -> false
      dt -> DateTime.diff(policy.now, dt) < policy.settlement_delay_seconds
    end
  end

  defp parse_time(%DateTime{} = dt), do: dt

  defp parse_time(s) when is_binary(s) do
    case DateTime.from_iso8601(s) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_time(_), do: nil

  defp item(match_key, state, kind, source, reason, records, amount, txid, vout) do
    %{
      match_key: "#{source}|#{match_key}",
      state: state,
      discrepancy_kind: kind,
      source: source,
      reason: reason,
      records: records,
      amount_sats: amount,
      txid: txid,
      vout: vout
    }
  end

  def summarize(items) do
    counts = Enum.frequencies_by(items, & &1.state)
    kinds = items |> Enum.filter(& &1.discrepancy_kind) |> Enum.frequencies_by(& &1.discrepancy_kind)
    total = length(items)
    matched = Map.get(counts, "matched", 0)

    %{
      "total" => total,
      "by_state" => counts,
      "by_kind" => kinds,
      "match_rate" => if(total == 0, do: nil, else: Float.round(matched / total, 4))
    }
  end
end
