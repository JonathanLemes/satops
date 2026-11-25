defmodule SatOps.WalletMonitoring do
  import Ecto.Query
  alias SatOps.{Audit, Repo}
  alias SatOps.Blockchain.{Input, Output, Transaction}

  defmodule Wallet do
    use SatOps.Schema

    schema "watched_wallets" do
      field :environment_id, :binary_id
      field :name, :string
      field :kind, :string, default: "addresses"
      field :descriptor, :string
      field :derivation_limit, :integer, default: 20
      field :group_name, :string
      field :labels, {:array, :string}, default: []
      field :account_ref, :string
      has_many :addresses, SatOps.WalletMonitoring.Address
      timestamps()
    end

    def changeset(wallet, attrs) do
      wallet
      |> cast(attrs, [:environment_id, :name, :kind, :descriptor, :derivation_limit, :group_name, :labels, :account_ref])
      |> validate_required([:environment_id, :name, :kind])
      |> validate_length(:name, max: 80)
      |> validate_inclusion(:kind, ["addresses", "descriptor"])
      |> validate_number(:derivation_limit, greater_than: 0, less_than_or_equal_to: 1000)
      |> validate_descriptor()
      |> unique_constraint([:environment_id, :name])
    end

    defp validate_descriptor(changeset) do
      case {get_field(changeset, :kind), get_field(changeset, :descriptor)} do
        {"descriptor", nil} ->
          add_error(changeset, :descriptor, "is required for descriptor wallets")

        {"descriptor", d} ->
          if Regex.match?(~r/(xprv|tprv|[5KLc][1-9A-HJ-NP-Za-km-z]{50,51})/, d),
            do: add_error(changeset, :descriptor, "private keys are never accepted; use a public descriptor"),
            else: changeset

        _ ->
          changeset
      end
    end
  end

  defmodule Address do
    use Ecto.Schema

    schema "watched_addresses" do
      field :environment_id, :binary_id
      belongs_to :wallet, SatOps.WalletMonitoring.Wallet, type: :binary_id
      field :address, :string
      field :label, :string
      field :derivation_index, :integer
      field :inserted_at, :utc_datetime_usec
    end
  end

  @address_format ~r/^(bcrt1[02-9ac-hj-np-z]{8,87}|[mn2][1-9A-HJ-NP-Za-km-z]{25,39})$/

  def valid_regtest_address?(address), do: Regex.match?(@address_format, address)

  def list_wallets(environment_id) do
    Repo.all(
      from w in Wallet,
        where: w.environment_id == ^environment_id,
        order_by: w.name,
        preload: [addresses: ^from(a in Address, order_by: a.id)]
    )
  end

  def get_wallet(id), do: Repo.get(Wallet, id) |> Repo.preload(addresses: from(a in Address, order_by: a.id))

  def create_wallet(attrs, actor, deriver \\ &derive_addresses/2) do
    Repo.transaction(fn ->
      with {:ok, wallet} <- %Wallet{} |> Wallet.changeset(attrs) |> Repo.insert(),
           {:ok, _} <- add_initial_addresses(wallet, attrs, deriver) do
        Audit.record!(actor, "wallet.created", resource: wallet, changes: %{name: wallet.name, kind: wallet.kind})
        get_wallet(wallet.id)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp add_initial_addresses(%Wallet{kind: "addresses"} = wallet, attrs, _deriver) do
    addresses = Map.get(attrs, :addresses) || Map.get(attrs, "addresses") || []
    insert_addresses(wallet, Enum.map(addresses, &normalize_address_input/1))
  end

  defp add_initial_addresses(%Wallet{kind: "descriptor"} = wallet, _attrs, deriver) do
    with {:ok, addresses} <- deriver.(wallet, wallet.derivation_limit) do
      insert_addresses(
        wallet,
        addresses |> Enum.with_index() |> Enum.map(fn {a, i} -> %{address: a, label: nil, derivation_index: i} end)
      )
    end
  end

  defp normalize_address_input(a) when is_binary(a), do: %{address: String.trim(a), label: nil}
  defp normalize_address_input(%{"address" => a} = m), do: %{address: String.trim(a), label: m["label"]}
  defp normalize_address_input(%{address: a} = m), do: %{address: String.trim(a), label: m[:label]}

  def add_address(%Wallet{} = wallet, address, label, actor) do
    Repo.transaction(fn ->
      case insert_addresses(wallet, [%{address: String.trim(address), label: label}]) do
        {:ok, _} ->
          Audit.record!(actor, "wallet.address_added", resource: wallet, changes: %{label: label})
          get_wallet(wallet.id)

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  defp insert_addresses(wallet, entries) do
    case Enum.reject(entries, &valid_regtest_address?(&1.address)) do
      [] ->
        now = DateTime.utc_now()

        rows =
          Enum.map(entries, fn e ->
            %{
              environment_id: Ecto.UUID.dump!(wallet.environment_id),
              wallet_id: Ecto.UUID.dump!(wallet.id),
              address: e.address,
              label: e[:label],
              derivation_index: e[:derivation_index],
              inserted_at: now
            }
          end)

        {:ok,
         Repo.insert_all("watched_addresses", rows, on_conflict: :nothing, conflict_target: [:wallet_id, :address])}

      invalid ->
        {:error, "invalid regtest addresses: #{Enum.map_join(invalid, ", ", & &1.address)}"}
    end
  end

  def derive_addresses(%Wallet{} = wallet, limit) do
    with {:ok, integration} <- SatOps.Blockchain.reference_node(wallet.environment_id),
         {:ok, creds} <- SatOps.Integrations.credentials(integration) do
      rpc = SatOps.Integrations.Adapters.BitcoinCore.rpc(integration, creds)
      alias SatOps.Infrastructure.Bitcoin.RPC

      with {:ok, %{"descriptor" => checked}} <- RPC.call(rpc, "getdescriptorinfo", [wallet.descriptor]),
           {:ok, addresses} <- RPC.call(rpc, "deriveaddresses", [checked, [0, limit - 1]]) do
        {:ok, addresses}
      else
        {:ok, _} -> {:ok, []}
        {:error, {:rpc, _, msg}} -> {:error, "descriptor rejected by Bitcoin Core: #{msg}"}
        {:error, reason} -> {:error, SatOps.Integrations.format_error(reason)}
      end
    else
      {:error, reason} -> {:error, "no reachable node to derive addresses: #{inspect(reason)}"}
    end
  end

  def delete_wallet(%Wallet{} = wallet, actor) do
    Repo.transaction(fn ->
      Repo.delete!(wallet)
      Audit.record!(actor, "wallet.deleted", resource: wallet)
      wallet
    end)
  end

  defp scope_addresses(environment_id, nil),
    do: from(a in Address, where: a.environment_id == ^environment_id, distinct: true, select: a.address)

  defp scope_addresses(environment_id, wallet_ids) when is_list(wallet_ids),
    do:
      from(a in Address,
        where: a.environment_id == ^environment_id and a.wallet_id in ^wallet_ids,
        distinct: true,
        select: a.address
      )

  def utxos(environment_id, wallet_ids \\ nil) do
    addresses = scope_addresses(environment_id, wallet_ids)

    spent =
      from i in Input,
        join: t in Transaction,
        on: t.environment_id == i.environment_id and t.txid == i.txid,
        where: i.environment_id == ^environment_id and t.status in ["confirmed", "pending", "unconfirmed"],
        select: %{txid: i.prev_txid, vout: i.prev_vout, spender_status: t.status}

    Repo.all(
      from o in Output,
        join: t in Transaction,
        on: t.environment_id == o.environment_id and t.txid == o.txid,
        left_join: s in subquery(spent),
        on: s.txid == o.txid and s.vout == o.vout,
        where:
          o.environment_id == ^environment_id and o.address in subquery(addresses) and
            t.status in ["confirmed", "pending", "unconfirmed"] and
            (is_nil(s.txid) or s.spender_status != "confirmed"),
        distinct: [o.txid, o.vout],
        order_by: [o.txid, o.vout],
        select: %{
          txid: o.txid,
          vout: o.vout,
          address: o.address,
          value_sats: o.value_sats,
          status: t.status,
          block_height: t.block_height,
          spent_unconfirmed: not is_nil(s.txid)
        }
    )
  end

  def balance(environment_id, required_confirmations, wallet_ids \\ nil) do
    tip = SatOps.Blockchain.tip_height(environment_id)

    Enum.reduce(utxos(environment_id, wallet_ids), %{confirmed_sats: 0, pending_sats: 0, utxo_count: 0}, fn u, acc ->
      confs = SatOps.Blockchain.TxState.confirmations(tip, u.block_height)

      cond do
        u.spent_unconfirmed ->
          acc

        u.status == "confirmed" and confs >= required_confirmations ->
          %{acc | confirmed_sats: acc.confirmed_sats + u.value_sats, utxo_count: acc.utxo_count + 1}

        true ->
          %{acc | pending_sats: acc.pending_sats + u.value_sats, utxo_count: acc.utxo_count + 1}
      end
    end)
  end

  def wallet_balances(environment_id, required_confirmations) do
    list_wallets(environment_id)
    |> Enum.map(fn w -> {w, balance(environment_id, required_confirmations, [w.id])} end)
  end

  def history(environment_id, wallet_ids \\ nil, limit \\ 100) do
    addresses = scope_addresses(environment_id, wallet_ids)

    received =
      from o in Output,
        join: t in Transaction,
        on: t.environment_id == o.environment_id and t.txid == o.txid,
        where: o.environment_id == ^environment_id and o.address in subquery(addresses),
        group_by: [t.txid, t.status, t.block_height, t.first_seen_at],
        select: %{
          txid: t.txid,
          status: t.status,
          block_height: t.block_height,
          first_seen_at: t.first_seen_at,
          received: sum(o.value_sats),
          sent: 0
        }

    sent =
      from i in Input,
        join: o in Output,
        on: o.environment_id == i.environment_id and o.txid == i.prev_txid and o.vout == i.prev_vout,
        join: t in Transaction,
        on: t.environment_id == i.environment_id and t.txid == i.txid,
        where: i.environment_id == ^environment_id and o.address in subquery(addresses),
        group_by: [t.txid, t.status, t.block_height, t.first_seen_at],
        select: %{
          txid: t.txid,
          status: t.status,
          block_height: t.block_height,
          first_seen_at: t.first_seen_at,
          received: 0,
          sent: sum(o.value_sats)
        }

    Repo.all(
      from u in subquery(union_all(received, ^sent)),
        group_by: [u.txid, u.status, u.block_height, u.first_seen_at],
        order_by: [desc: u.first_seen_at],
        limit: ^limit,
        select: %{
          txid: u.txid,
          status: u.status,
          block_height: u.block_height,
          first_seen_at: u.first_seen_at,
          received_sats: type(sum(u.received), :integer),
          sent_sats: type(sum(u.sent), :integer)
        }
    )
  end

  def internal_transfers(environment_id, limit \\ 50) do
    Repo.all(
      from i in Input,
        join: src in Output,
        on: src.environment_id == i.environment_id and src.txid == i.prev_txid and src.vout == i.prev_vout,
        join: wa in Address,
        on: wa.environment_id == src.environment_id and wa.address == src.address,
        join: dst in Output,
        on: dst.environment_id == i.environment_id and dst.txid == i.txid,
        join: wb in Address,
        on: wb.environment_id == dst.environment_id and wb.address == dst.address and wb.wallet_id != wa.wallet_id,
        where: i.environment_id == ^environment_id,
        distinct: [i.txid, wa.wallet_id, wb.wallet_id],
        limit: ^limit,
        select: %{txid: i.txid, from_wallet_id: wa.wallet_id, to_wallet_id: wb.wallet_id, value_sats: dst.value_sats}
    )
  end

  def watched_address_map(environment_id, addresses) do
    Repo.all(
      from a in Address,
        join: w in Wallet,
        on: w.id == a.wallet_id,
        where: a.environment_id == ^environment_id and a.address in ^addresses,
        select: {a.address, %{wallet: w.name, account_ref: w.account_ref, label: a.label}}
    )
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end
end
