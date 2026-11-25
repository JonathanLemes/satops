defmodule SatOps.Ledger.Draft do
  @enforce_keys [:operation_id, :entry_kind, :rule_name, :rule_version, :postings]
  defstruct [
    :operation_id,
    :entry_kind,
    :rule_name,
    :rule_version,
    :description,
    :reverses_journal_id,
    postings: [],
    metadata: %{}
  ]

  def debit(code, amount, asset \\ "BTC"),
    do: %{account_code: code, direction: "debit", amount_sats: amount, asset: asset}

  def credit(code, amount, asset \\ "BTC"),
    do: %{account_code: code, direction: "credit", amount_sats: amount, asset: asset}

  def validate(%__MODULE__{postings: postings} = draft) do
    cond do
      length(postings) < 2 ->
        {:error, :too_few_postings}

      Enum.any?(postings, fn p -> not is_integer(p.amount_sats) or p.amount_sats <= 0 end) ->
        {:error, :invalid_amount}

      not balanced?(postings) ->
        {:error, :unbalanced}

      true ->
        {:ok, draft}
    end
  end

  def balanced?(postings) do
    postings
    |> Enum.group_by(& &1.asset)
    |> Enum.all?(fn {_asset, ps} ->
      Enum.sum(for p <- ps, p.direction == "debit", do: p.amount_sats) ==
        Enum.sum(for p <- ps, p.direction == "credit", do: p.amount_sats)
    end)
  end

  def fingerprint(%__MODULE__{} = d) do
    canonical =
      d.postings
      |> Enum.map(&{&1.account_code, &1.direction, &1.amount_sats, &1.asset})
      |> Enum.sort()

    :crypto.hash(:sha256, :erlang.term_to_binary({d.rule_name, d.rule_version, d.reverses_journal_id, canonical}))
    |> Base.encode16(case: :lower)
  end
end
