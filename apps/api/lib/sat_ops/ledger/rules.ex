defmodule SatOps.Ledger.Rules do
  alias SatOps.Ledger.Rules

  @rules %{
    {"deposit_detected", 1} => Rules.DepositDetected,
    {"deposit_confirmed", 1} => Rules.DepositConfirmed,
    {"deposit_reversed", 1} => Rules.DepositReversed,
    {"deposit_cancelled", 1} => Rules.DepositCancelled,
    {"internal_transfer", 1} => Rules.InternalTransfer,
    {"withdrawal_requested", 1} => Rules.WithdrawalRequested,
    {"withdrawal_confirmed", 1} => Rules.WithdrawalConfirmed,
    {"withdrawal_failed", 1} => Rules.WithdrawalFailed,
    {"compensating_entry", 1} => Rules.CompensatingEntry
  }

  @current %{
    "deposit_detected" => 1,
    "deposit_confirmed" => 1,
    "deposit_reversed" => 1,
    "deposit_cancelled" => 1,
    "internal_transfer" => 1,
    "withdrawal_requested" => 1,
    "withdrawal_confirmed" => 1,
    "withdrawal_failed" => 1,
    "compensating_entry" => 1
  }

  def all,
    do:
      @rules
      |> Enum.map(fn {{name, version}, mod} ->
        %{name: name, version: version, module: mod, current: @current[name] == version}
      end)

  def fetch(name, version) do
    case Map.fetch(@rules, {name, version}) do
      {:ok, mod} -> {:ok, mod}
      :error -> {:error, {:unknown_rule, name, version}}
    end
  end

  def current_version(name), do: Map.fetch!(@current, name)

  def build(name, facts, version \\ nil) do
    version = version || current_version(name)

    with {:ok, mod} <- fetch(name, version),
         {:ok, draft} <- mod.build(facts) do
      SatOps.Ledger.Draft.validate(%{draft | rule_name: name, rule_version: version})
    end
  end
end

defmodule SatOps.Ledger.Rules.Helpers do
  def positive(amount) when is_integer(amount) and amount > 0, do: :ok
  def positive(_), do: {:error, :invalid_amount}

  def ref(ref) do
    if SatOps.Ledger.Chart.valid_ref?(ref), do: :ok, else: {:error, :invalid_account_ref}
  end
end

defmodule SatOps.Ledger.Rules.DepositDetected do
  import SatOps.Ledger.Rules.Helpers
  alias SatOps.Ledger.{Chart, Draft}

  def build(%{operation_id: op, generation: g, account_ref: ref, amount_sats: amt, txid: txid, vout: vout}) do
    with :ok <- positive(amt), :ok <- ref(ref) do
      {:ok,
       %Draft{
         operation_id: op,
         entry_kind: "detected:g#{g}",
         rule_name: nil,
         rule_version: nil,
         description: "Deposit detected #{txid}:#{vout}",
         postings: [Draft.debit(Chart.onchain_unconfirmed(), amt), Draft.credit(Chart.pending(ref), amt)],
         metadata: %{"txid" => txid, "vout" => vout}
       }}
    end
  end
end

defmodule SatOps.Ledger.Rules.DepositConfirmed do
  import SatOps.Ledger.Rules.Helpers
  alias SatOps.Ledger.{Chart, Draft}

  def build(%{operation_id: op, generation: g, account_ref: ref, amount_sats: amt, txid: txid, vout: vout} = f) do
    with :ok <- positive(amt), :ok <- ref(ref) do
      {:ok,
       %Draft{
         operation_id: op,
         entry_kind: "confirmed:g#{g}",
         rule_name: nil,
         rule_version: nil,
         description: "Deposit confirmed #{txid}:#{vout} with #{f[:confirmations]} confirmations",
         postings: [
           Draft.debit(Chart.onchain(), amt),
           Draft.credit(Chart.onchain_unconfirmed(), amt),
           Draft.debit(Chart.pending(ref), amt),
           Draft.credit(Chart.available(ref), amt)
         ],
         metadata: %{
           "txid" => txid,
           "vout" => vout,
           "block_hash" => f[:block_hash],
           "confirmations" => f[:confirmations]
         }
       }}
    end
  end
end

defmodule SatOps.Ledger.Rules.DepositReversed do
  import SatOps.Ledger.Rules.Helpers
  alias SatOps.Ledger.{Chart, Draft}

  def build(%{operation_id: op, generation: g, account_ref: ref, amount_sats: amt, available_sats: available} = f) do
    with :ok <- positive(amt), :ok <- ref(ref) do
      from_available = min(max(available, 0), amt)
      shortfall = amt - from_available

      customer_side =
        [
          if(from_available > 0, do: Draft.debit(Chart.available(ref), from_available)),
          if(shortfall > 0, do: Draft.debit(Chart.receivable(ref), shortfall))
        ]
        |> Enum.reject(&is_nil/1)

      {:ok,
       %Draft{
         operation_id: op,
         entry_kind: "reversed:g#{g}",
         rule_name: nil,
         rule_version: nil,
         description: "Deposit reversed after #{f[:reason] || "chain change"}",
         postings: customer_side ++ [Draft.credit(Chart.onchain(), amt)],
         metadata: %{"reason" => f[:reason], "shortfall_sats" => shortfall, "previous_block" => f[:previous_block]}
       }}
    end
  end
end

defmodule SatOps.Ledger.Rules.DepositCancelled do
  import SatOps.Ledger.Rules.Helpers
  alias SatOps.Ledger.{Chart, Draft}

  def build(%{operation_id: op, generation: g, account_ref: ref, amount_sats: amt} = f) do
    with :ok <- positive(amt), :ok <- ref(ref) do
      {:ok,
       %Draft{
         operation_id: op,
         entry_kind: "cancelled:g#{g}",
         rule_name: nil,
         rule_version: nil,
         description: "Unconfirmed deposit cancelled: #{f[:reason]}",
         postings: [Draft.debit(Chart.pending(ref), amt), Draft.credit(Chart.onchain_unconfirmed(), amt)],
         metadata: %{"reason" => f[:reason]}
       }}
    end
  end
end

defmodule SatOps.Ledger.Rules.InternalTransfer do
  import SatOps.Ledger.Rules.Helpers
  alias SatOps.Ledger.{Chart, Draft}

  def build(%{operation_id: op, from_ref: from, to_ref: to, amount_sats: amt}) do
    with :ok <- positive(amt), :ok <- ref(from), :ok <- ref(to), :ok <- distinct(from, to) do
      {:ok,
       %Draft{
         operation_id: op,
         entry_kind: "transfer",
         rule_name: nil,
         rule_version: nil,
         description: "Internal transfer #{from} to #{to}",
         postings: [Draft.debit(Chart.available(from), amt), Draft.credit(Chart.available(to), amt)]
       }}
    end
  end

  defp distinct(a, a), do: {:error, :same_account}
  defp distinct(_, _), do: :ok
end

defmodule SatOps.Ledger.Rules.WithdrawalRequested do
  import SatOps.Ledger.Rules.Helpers
  alias SatOps.Ledger.{Chart, Draft}

  def build(%{operation_id: op, account_ref: ref, amount_sats: amt} = f) do
    fee = f[:fee_sats] || 0
    total = amt + fee

    with :ok <- positive(amt), :ok <- ref(ref) do
      {:ok,
       %Draft{
         operation_id: op,
         entry_kind: "reserved",
         rule_name: nil,
         rule_version: nil,
         description: "Funds reserved for withdrawal",
         postings: [Draft.debit(Chart.available(ref), total), Draft.credit(Chart.reserved(ref), total)],
         metadata: %{"amount_sats" => amt, "fee_sats" => fee}
       }}
    end
  end
end

defmodule SatOps.Ledger.Rules.WithdrawalConfirmed do
  import SatOps.Ledger.Rules.Helpers
  alias SatOps.Ledger.{Chart, Draft}

  def build(%{operation_id: op, account_ref: ref, amount_sats: amt} = f) do
    total = amt + (f[:fee_sats] || 0)

    with :ok <- positive(amt), :ok <- ref(ref) do
      {:ok,
       %Draft{
         operation_id: op,
         entry_kind: "settled",
         rule_name: nil,
         rule_version: nil,
         description: "Withdrawal settled on-chain",
         postings: [Draft.debit(Chart.reserved(ref), total), Draft.credit(Chart.onchain(), total)],
         metadata: %{"txid" => f[:txid]}
       }}
    end
  end
end

defmodule SatOps.Ledger.Rules.WithdrawalFailed do
  import SatOps.Ledger.Rules.Helpers
  alias SatOps.Ledger.{Chart, Draft}

  def build(%{operation_id: op, account_ref: ref, amount_sats: amt} = f) do
    total = amt + (f[:fee_sats] || 0)

    with :ok <- positive(amt), :ok <- ref(ref) do
      {:ok,
       %Draft{
         operation_id: op,
         entry_kind: "released",
         rule_name: nil,
         rule_version: nil,
         description: "Withdrawal failed, funds released",
         postings: [Draft.debit(Chart.reserved(ref), total), Draft.credit(Chart.available(ref), total)],
         metadata: %{"reason" => f[:reason]}
       }}
    end
  end
end

defmodule SatOps.Ledger.Rules.CompensatingEntry do
  alias SatOps.Ledger.Draft

  def build(%{operation_id: op, journal_id: journal_id, postings: postings, reason: reason})
      when is_binary(reason) and reason != "" do
    flipped =
      Enum.map(postings, fn p ->
        %{
          account_code: p.account_code,
          asset: p.asset,
          amount_sats: p.amount_sats,
          direction: if(p.direction == "debit", do: "credit", else: "debit")
        }
      end)

    {:ok,
     %Draft{
       operation_id: op,
       entry_kind: "compensation:#{journal_id}",
       rule_name: nil,
       rule_version: nil,
       reverses_journal_id: journal_id,
       description: "Compensating entry: #{reason}",
       postings: flipped,
       metadata: %{"reason" => reason}
     }}
  end

  def build(_), do: {:error, :reason_required}
end
