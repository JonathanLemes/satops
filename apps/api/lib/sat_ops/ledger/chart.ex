defmodule SatOps.Ledger.Chart do
  def onchain, do: "assets:onchain"
  def onchain_unconfirmed, do: "assets:onchain-unconfirmed"
  def receivable(ref), do: "assets:receivables:#{ref}"
  def available(ref), do: "liabilities:customers:#{ref}:available"
  def pending(ref), do: "liabilities:customers:#{ref}:pending"
  def reserved(ref), do: "liabilities:customers:#{ref}:reserved"
  def adjustments, do: "equity:adjustments"

  def account_spec(code) do
    case String.split(code, ":") do
      ["assets" | _] ->
        {:ok, %{type: "asset", normal_balance: "debit", restricted: false, owner_ref: owner(code)}}

      ["liabilities", "customers", ref, "available"] ->
        {:ok, %{type: "liability", normal_balance: "credit", restricted: true, owner_ref: ref}}

      ["liabilities", "customers", ref, "reserved"] ->
        {:ok, %{type: "liability", normal_balance: "credit", restricted: true, owner_ref: ref}}

      ["liabilities", "customers", ref, "pending"] ->
        {:ok, %{type: "liability", normal_balance: "credit", restricted: false, owner_ref: ref}}

      ["liabilities" | _] ->
        {:ok, %{type: "liability", normal_balance: "credit", restricted: false, owner_ref: nil}}

      ["equity" | _] ->
        {:ok, %{type: "equity", normal_balance: "credit", restricted: false, owner_ref: nil}}

      ["revenue" | _] ->
        {:ok, %{type: "revenue", normal_balance: "credit", restricted: false, owner_ref: nil}}

      ["expenses" | _] ->
        {:ok, %{type: "expense", normal_balance: "debit", restricted: false, owner_ref: nil}}

      _ ->
        {:error, {:unknown_account_code, code}}
    end
  end

  defp owner(code) do
    case String.split(code, ":") do
      ["assets", "receivables", ref] -> ref
      _ -> nil
    end
  end

  def valid_ref?(ref), do: is_binary(ref) and Regex.match?(~r/^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$/, ref)
end
