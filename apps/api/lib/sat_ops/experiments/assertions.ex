defmodule SatOps.Experiments.Assertions do
  alias SatOps.{Blockchain, Ledger, Reconciliation}
  alias SatOps.Experiments.Context
  alias SatOps.Integrations.ConfigValidation

  @types ~w(ledger.balance_equals ledger.is_balanced ledger.duplicate_credits reconciliation.open_discrepancies
            reconciliation.run_status blockchain.confirmations blockchain.transaction_status blockchain.synced
            fintech.balance_equals step.result_equals integration.webhook_receipts)

  def types, do: @types

  def validate(%{"type" => type} = a) when type in @types do
    cond do
      type == "ledger.balance_equals" and not (is_binary(a["account"]) and is_integer(a["amountSats"])) ->
        {:error, "ledger.balance_equals needs account and amountSats"}

      type == "blockchain.confirmations" and not (is_binary(a["transactionRef"]) and is_integer(a["expected"])) ->
        {:error, "blockchain.confirmations needs transactionRef and expected"}

      type == "fintech.balance_equals" and not (is_binary(a["customerRef"]) and is_integer(a["amountSats"])) ->
        {:error, "fintech.balance_equals needs customerRef and amountSats"}

      type == "step.result_equals" and not (is_binary(a["step"]) and is_binary(a["field"])) ->
        {:error, "step.result_equals needs step and field"}

      true ->
        :ok
    end
  end

  def validate(%{"type" => type}), do: {:error, "unsupported assertion type #{type}"}
  def validate(_), do: {:error, "assertion type is required"}

  def evaluate(assertion, ctx) do
    timeout = ConfigValidation.parse_duration(assertion["timeout"], 0) |> min(300_000)
    deadline = System.monotonic_time(:millisecond) + timeout
    poll(assertion, ctx, deadline, 1)
  end

  defp poll(assertion, ctx, deadline, attempt) do
    result =
      try do
        check(assertion["type"], assertion, Context.build(ctx.run, ctx.env))
      rescue
        e -> {:error, Exception.message(e)}
      end

    case result do
      {:pass, expected, actual} ->
        finish(assertion, "passed", expected, actual, "condition satisfied", attempt)

      {:fail, expected, actual, message} ->
        if System.monotonic_time(:millisecond) >= deadline do
          outcome = if ConfigValidation.parse_duration(assertion["timeout"], 0) == 0, do: "false", else: "timed_out"
          finish(assertion, outcome, expected, actual, message, attempt)
        else
          Process.sleep(SatOps.Backoff.delay(attempt, base_ms: 250, max_ms: 3_000, jitter: 0.1))
          poll(assertion, ctx, deadline, attempt + 1)
        end

      {:unavailable, message} ->
        if System.monotonic_time(:millisecond) >= deadline do
          finish(assertion, "source_unavailable", nil, nil, message, attempt)
        else
          Process.sleep(SatOps.Backoff.delay(attempt, base_ms: 500, max_ms: 3_000, jitter: 0.1))
          poll(assertion, ctx, deadline, attempt + 1)
        end

      {:error, message} ->
        finish(assertion, "error", nil, nil, message, attempt)
    end
  end

  defp finish(assertion, outcome, expected, actual, message, attempts) do
    %{
      type: assertion["type"],
      outcome: outcome,
      expected: wrap(expected),
      actual: wrap(actual),
      message: message,
      attempts: attempts,
      params: assertion
    }
  end

  defp wrap(nil), do: nil
  defp wrap(v) when is_map(v), do: v
  defp wrap(v), do: %{"value" => v}

  defp compare(expected, actual, message) do
    if expected == actual, do: {:pass, expected, actual}, else: {:fail, expected, actual, message}
  end

  defp check("ledger.balance_equals", a, ctx) do
    with {:ok, ref} <- resolve(ctx, a["account"]) do
      bucket = a["bucket"] || "available"
      code = apply(SatOps.Ledger.Chart, String.to_existing_atom(bucket), [ref])
      actual = Ledger.balance(ctx.env.id, code)
      compare(a["amountSats"], actual, "#{code} is #{actual} sats, expected #{a["amountSats"]}")
    end
  end

  defp check("ledger.is_balanced", _a, ctx) do
    r = Ledger.verify_invariants(ctx.env.id)

    if r.ok,
      do: {:pass, true, true},
      else:
        {:fail, true, false,
         "ledger invariants violated: #{inspect(Map.take(r, [:unbalanced_journals, :projection_drift, :negative_restricted]))}"}
  end

  defp check("ledger.duplicate_credits", a, ctx) do
    actual = Ledger.duplicate_credits(ctx.env.id)
    compare(a["expected"] || 0, actual, "#{actual} outpoints credited more than once")
  end

  defp check("reconciliation.open_discrepancies", a, ctx) do
    case Reconciliation.list_runs(ctx.env.id, 1) do
      [%{status: "completed", finished_at: %DateTime{} = at} | _] ->
        if ctx.run.started_at && DateTime.compare(at, ctx.run.started_at) == :lt,
          do: {:unavailable, "no completed reconciliation since the experiment started"},
          else: count_discrepancies(a, ctx)

      [%{status: status} | _] ->
        {:unavailable, "latest reconciliation is #{status}; open discrepancies cannot be trusted"}

      [] ->
        {:unavailable, "no reconciliation run exists"}
    end
  end

  defp check("reconciliation.run_status", a, ctx) do
    case Reconciliation.list_runs(ctx.env.id, 1) do
      [run | _] -> compare(a["expected"] || "completed", run.status, "latest reconciliation is #{run.status}")
      [] -> {:fail, a["expected"], nil, "no reconciliation run found"}
    end
  end

  defp check("blockchain.confirmations", a, ctx) do
    with {:ok, txid} <- resolve(ctx, a["transactionRef"]) do
      tx = Blockchain.get_transaction(ctx.env.id, txid)
      actual = Blockchain.confirmations(ctx.env.id, tx)

      if actual >= a["expected"],
        do: {:pass, a["expected"], actual},
        else: {:fail, a["expected"], actual, "#{actual} confirmations"}
    end
  end

  defp check("blockchain.transaction_status", a, ctx) do
    with {:ok, txid} <- resolve(ctx, a["transactionRef"]) do
      tx = Blockchain.get_transaction(ctx.env.id, txid)
      compare(a["expected"], tx && tx.status, "transaction is #{(tx && tx.status) || "unknown to SatWatch"}")
    end
  end

  defp check("blockchain.synced", _a, ctx) do
    with {:ok, _i, rpc} <- Context.node(ctx, nil),
         {:ok, best} <- SatOps.Infrastructure.Bitcoin.RPC.call(rpc, "getbestblockhash") do
      tip = Blockchain.tip(ctx.env.id)
      compare(best, tip && tip.hash, "local tip #{tip && tip.hash} differs from node tip #{best}")
    else
      {:error, reason} -> {:unavailable, "reference node unavailable: #{inspect(reason)}"}
    end
  end

  defp check("fintech.balance_equals", a, ctx) do
    with {:ok, customer} <- resolve(ctx, a["customerRef"]),
         {:ok, integration, token} <- Context.fintech(ctx) do
      case SatOps.Integrations.Adapters.DemoFintech.fetch_balances(integration, token, []) do
        {:ok, %{balances: balances}} ->
          b = Enum.find(balances, &(&1["account_ref"] == customer)) || %{}
          actual = b["available_sats"] || 0
          compare(a["amountSats"], actual, "demo fintech reports #{actual} sats available")

        {:error, reason} ->
          {:unavailable, "demo fintech unavailable: #{SatOps.Integrations.format_error(reason)}"}
      end
    else
      {:error, reason} when is_binary(reason) -> {:error, reason}
    end
  end

  defp check("step.result_equals", a, ctx) do
    import Ecto.Query

    step =
      SatOps.Repo.one(from s in SatOps.Experiments.Step, where: s.run_id == ^ctx.run.id and s.step_key == ^a["step"])

    actual = step && step.result && step.result[a["field"]]
    compare(a["expected"], actual, "#{a["step"]}.#{a["field"]} is #{inspect(actual)}")
  end

  defp check("integration.webhook_receipts", a, ctx) do
    import Ecto.Query

    counts =
      SatOps.Repo.one(
        from r in "webhook_receipts",
          join: i in SatOps.Integrations.Integration,
          on: i.id == r.integration_id,
          where: i.environment_id == ^ctx.env.id and r.received_at >= ^ctx.run.started_at,
          select: %{total: count(r.id), distinct: count(r.delivery_id, :distinct)}
      )

    if counts.total == counts.distinct and counts.total >= (a["atLeast"] || 0),
      do: {:pass, %{"unique" => true}, counts},
      else: {:fail, %{"unique" => true, "atLeast" => a["atLeast"]}, counts, "webhook receipts #{inspect(counts)}"}
  end

  defp count_discrepancies(a, ctx) do
    discrepancies =
      Reconciliation.list_discrepancies(ctx.env.id, states: ["open", "investigating"], kind: a["kind"], limit: 500)
      |> Enum.filter(&(is_nil(a["source"]) or &1.evidence["source"] == a["source"]))
      |> filter_account(a, ctx)

    actual = length(discrepancies)

    cond do
      is_integer(a["atLeast"]) and actual >= a["atLeast"] ->
        {:pass, %{"atLeast" => a["atLeast"]}, actual}

      is_integer(a["atLeast"]) ->
        {:fail, %{"atLeast" => a["atLeast"]}, actual, "#{actual} open discrepancies"}

      true ->
        compare(
          a["expected"] || 0,
          actual,
          "#{actual} open discrepancies: #{discrepancies |> Enum.map(& &1.kind) |> Enum.uniq() |> Enum.join(", ")}"
        )
    end
  end

  defp filter_account(discrepancies, %{"account" => key}, ctx) when is_binary(key) do
    {:ok, ref} = resolve(ctx, key)
    Enum.filter(discrepancies, &String.contains?(&1.match_key <> Jason.encode!(&1.evidence), ref))
  end

  defp filter_account(discrepancies, _a, _ctx), do: discrepancies

  defp resolve(ctx, key) do
    case Context.ref(ctx, key) do
      {:ok, v} -> {:ok, v}
      {:error, _} -> {:ok, key}
    end
  end
end
