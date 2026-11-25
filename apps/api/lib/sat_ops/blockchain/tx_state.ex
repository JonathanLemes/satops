defmodule SatOps.Blockchain.TxState do
  @statuses ~w(observed pending confirmed unconfirmed conflicted replaced unknown)

  @transitions %{
    nil => ~w(observed pending confirmed),
    "observed" => ~w(pending confirmed conflicted replaced unknown),
    "pending" => ~w(confirmed conflicted replaced unknown),
    "confirmed" => ~w(unconfirmed),
    "unconfirmed" => ~w(pending confirmed conflicted replaced unknown),
    "unknown" => ~w(pending confirmed conflicted replaced),
    "conflicted" => ~w(confirmed unconfirmed pending),
    "replaced" => ~w(confirmed)
  }

  def statuses, do: @statuses

  def transition(from, from), do: :noop

  def transition(from, to) do
    if to in Map.get(@transitions, from, []), do: {:ok, to}, else: {:error, {:invalid_transition, from, to}}
  end

  def confirmations(_tip_height, nil), do: 0
  def confirmations(nil, _block_height), do: 0
  def confirmations(tip_height, block_height) when tip_height >= block_height, do: tip_height - block_height + 1
  def confirmations(_, _), do: 0

  def event_for("confirmed"), do: "transaction.confirmed"
  def event_for("unconfirmed"), do: "transaction.unconfirmed"
  def event_for("replaced"), do: "transaction.replaced"
  def event_for("conflicted"), do: "transaction.conflicted"
  def event_for("pending"), do: "transaction.observed"
  def event_for(_), do: nil
end
