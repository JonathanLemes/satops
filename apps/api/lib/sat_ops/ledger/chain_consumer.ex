defmodule SatOps.Ledger.ChainConsumer do
  @behaviour SatOps.Events.Consumer
  alias SatOps.{Environments, WalletMonitoring}
  alias SatOps.Ledger.Deposits

  @tx_events ~w(transaction.observed transaction.confirmed transaction.unconfirmed transaction.conflicted transaction.replaced)

  @impl true
  def name, do: "ledger.chain"

  @impl true
  def interested?(type), do: type in @tx_events or type == "block.connected"

  @impl true
  def handle(%{event_type: "block.connected"} = event) do
    env = Environments.get!(event.environment_id)
    ctx = %{correlation_id: event.correlation_id, causation_id: event.id}

    env.id
    |> Deposits.pending_operations()
    |> Enum.each(fn op ->
      {:ok, _} =
        Deposits.evaluate(
          env,
          %{txid: op.txid, vout: op.vout, amount_sats: op.amount_sats, account_ref: op.account_ref},
          ctx
        )
    end)

    :ok
  end

  def handle(%{event_type: type} = event) when type in @tx_events do
    env = Environments.get!(event.environment_id)
    outputs = event.payload["outputs"] || []
    addresses = outputs |> Enum.map(& &1["address"]) |> Enum.reject(&is_nil/1)
    watched = WalletMonitoring.watched_address_map(env.id, addresses)
    ctx = %{correlation_id: event.correlation_id, causation_id: event.id}

    results =
      for o <- outputs,
          refs = Map.get(watched, o["address"], []),
          ref = Enum.find_value(refs, & &1.account_ref),
          not is_nil(ref) do
        Deposits.evaluate(
          env,
          %{txid: event.payload["txid"], vout: o["vout"], amount_sats: o["value_sats"], account_ref: ref},
          ctx
        )
      end

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
