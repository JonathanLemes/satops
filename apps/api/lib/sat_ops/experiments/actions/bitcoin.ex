defmodule SatOps.Experiments.Actions.Base do
  defmacro __using__(opts) do
    quote do
      @behaviour SatOps.Experiments.Action
      alias SatOps.Experiments.Context
      alias SatOps.Infrastructure.Bitcoin.RPC

      @impl true
      def name, do: unquote(opts[:name])
      @impl true
      def idempotency, do: unquote(opts[:idempotency])
      @impl true
      def capabilities, do: unquote(opts[:capabilities] || [])
      @impl true
      def validate(_params), do: :ok
      defoverridable validate: 1

      defp int(params, key, min, max) do
        case params[key] do
          v when is_integer(v) and v >= min and v <= max -> :ok
          _ -> {:error, "#{key} must be an integer between #{min} and #{max}"}
        end
      end

      defp str(params, key) do
        case params[key] do
          v when is_binary(v) and v != "" -> :ok
          _ -> {:error, "#{key} is required"}
        end
      end

      defp rpc_error({:rpc, code, msg}), do: "bitcoin RPC #{code}: #{msg}"
      defp rpc_error(other), do: SatOps.Integrations.format_error(other)
    end
  end
end

defmodule SatOps.Experiments.Actions.Bitcoin.Helpers do
  alias SatOps.Infrastructure.Bitcoin.RPC

  def ensure_wallet(rpc, wallet) do
    base = %{rpc | wallet: nil}

    case RPC.call(base, "createwallet", [wallet]) do
      {:ok, _} ->
        :ok

      {:error, {:rpc, -4, _}} ->
        case RPC.call(base, "loadwallet", [wallet]) do
          {:ok, _} -> :ok
          {:error, {:rpc, -35, _}} -> :ok
          {:error, reason} -> {:error, reason}
        end

      {:error, {:rpc, -35, _}} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  def mining_address(rpc, wallet) do
    with :ok <- ensure_wallet(rpc, wallet) do
      RPC.call(RPC.with_wallet(rpc, wallet), "getnewaddress", ["satlab-mining", "bech32"])
    end
  end
end

defmodule SatOps.Experiments.Actions.Bitcoin.CreateWallet do
  use SatOps.Experiments.Actions.Base,
    name: "bitcoin.create_wallet",
    idempotency: :natural,
    capabilities: ["bitcoin.rpc"]

  alias SatOps.Experiments.Actions.Bitcoin.Helpers

  @impl true
  def validate(p), do: str(p, "wallet")

  @impl true
  def run(p, ctx) do
    with {:ok, rpc} <- Context.rpc(ctx, p["node"]),
         :ok <- Helpers.ensure_wallet(rpc, p["wallet"]) do
      {:ok, %{"wallet" => p["wallet"]}}
    else
      {:error, r} -> {:error, rpc_error(r)}
    end
  end
end

defmodule SatOps.Experiments.Actions.Bitcoin.CreateAddress do
  use SatOps.Experiments.Actions.Base,
    name: "bitcoin.create_address",
    idempotency: :natural,
    capabilities: ["bitcoin.rpc"]

  alias SatOps.Experiments.Actions.Bitcoin.Helpers

  @impl true
  def validate(p) do
    with :ok <- str(p, "wallet"), do: str(p, "as")
  end

  @impl true
  def run(p, ctx) do
    with {:ok, rpc} <- Context.rpc(ctx, p["node"]),
         :ok <- Helpers.ensure_wallet(rpc, p["wallet"]),
         {:ok, address} <- RPC.call(RPC.with_wallet(rpc, p["wallet"]), "getnewaddress", [p["as"], "bech32"]) do
      {:ok, %{"address" => address, "refs" => %{p["as"] => address}}}
    else
      {:error, r} -> {:error, rpc_error(r)}
    end
  end
end

defmodule SatOps.Experiments.Actions.Bitcoin.EnsureFunds do
  use SatOps.Experiments.Actions.Base,
    name: "bitcoin.ensure_funds",
    idempotency: :verifiable,
    capabilities: ["bitcoin.rpc"]

  alias SatOps.Experiments.Actions.Bitcoin.Helpers

  @impl true
  def validate(p), do: int(p, "minimumSats", 1, 50_000_000_000)

  @impl true
  def run(p, ctx) do
    wallet = p["wallet"] || "satlab"

    with {:ok, rpc} <- Context.rpc(ctx, p["node"]),
         {:ok, address} <- Helpers.mining_address(rpc, wallet),
         wrpc = RPC.with_wallet(rpc, wallet),
         {:ok, mined} <- top_up(rpc, wrpc, address, p["minimumSats"], 0) do
      {:ok, balance} = RPC.call(wrpc, "getbalance")
      {:ok, %{"wallet" => wallet, "minedBlocks" => mined, "balanceSats" => RPC.btc_to_sats(balance)}}
    else
      {:error, r} -> {:error, rpc_error(r)}
    end
  end

  defp top_up(rpc, wrpc, address, minimum, mined) do
    {:ok, balance} = RPC.call(wrpc, "getbalance")

    cond do
      RPC.btc_to_sats(balance) >= minimum ->
        {:ok, mined}

      mined > 400 ->
        {:error, "could not reach #{minimum} sats after mining #{mined} blocks"}

      true ->
        count = if mined == 0, do: 101, else: 10

        with {:ok, _} <- RPC.call(%{rpc | wallet: nil}, "generatetoaddress", [count, address]) do
          top_up(rpc, wrpc, address, minimum, mined + count)
        end
    end
  end

  @impl true
  def verify(p, ctx, _checkpoint) do
    with {:ok, rpc} <- Context.rpc(ctx, p["node"], p["wallet"] || "satlab"),
         {:ok, balance} <- RPC.call(rpc, "getbalance") do
      if RPC.btc_to_sats(balance) >= p["minimumSats"],
        do: {:ok, %{"balanceSats" => RPC.btc_to_sats(balance)}},
        else: :not_done
    else
      _ -> :unknown
    end
  end
end

defmodule SatOps.Experiments.Actions.Bitcoin.MineBlocks do
  use SatOps.Experiments.Actions.Base, name: "bitcoin.mine_blocks", idempotency: :unsafe, capabilities: ["bitcoin.rpc"]
  alias SatOps.Experiments.Actions.Bitcoin.Helpers

  @impl true
  def validate(p), do: int(p, "count", 1, 200)

  @impl true
  def run(p, ctx) do
    with {:ok, rpc} <- Context.rpc(ctx, p["node"]),
         {:ok, address} <- Helpers.mining_address(rpc, p["wallet"] || "satlab"),
         {:ok, hashes} <- RPC.call(rpc, "generatetoaddress", [p["count"], address]) do
      {:ok, %{"blocks" => hashes, "tip" => List.last(hashes), "node" => p["node"]}}
    else
      {:error, r} -> {:error, rpc_error(r)}
    end
  end
end

defmodule SatOps.Experiments.Actions.Bitcoin.SendTransaction do
  use SatOps.Experiments.Actions.Base,
    name: "bitcoin.send_transaction",
    idempotency: :verifiable,
    capabilities: ["bitcoin.rpc"]

  @impl true
  def validate(p) do
    with :ok <- int(p, "amountSats", 546, 2_100_000_000_000_000),
         :ok <- str(p, "as") do
      if is_binary(p["to"]) or is_binary(p["toRef"]), do: :ok, else: {:error, "to or toRef is required"}
    end
  end

  @impl true
  def run(p, ctx) do
    wallet = p["fromWallet"] || "satlab"

    with {:ok, to} <- destination(p, ctx),
         {:ok, rpc} <- Context.rpc(ctx, p["node"], wallet),
         {:ok, txid} <- RPC.call(rpc, "sendtoaddress", [to, RPC.sats_to_btc(p["amountSats"])]) do
      {:ok, %{"txid" => txid, "to" => to, "amountSats" => p["amountSats"], "refs" => %{p["as"] => txid}}}
    else
      {:error, r} -> {:error, rpc_error(r)}
    end
  end

  @impl true
  def verify(p, ctx, _checkpoint) do
    with {:ok, to} <- destination(p, ctx),
         {:ok, rpc} <- Context.rpc(ctx, p["node"], p["fromWallet"] || "satlab"),
         {:ok, txs} <- RPC.call(rpc, "listtransactions", ["*", 500, 0, true]) do
      amount = RPC.sats_to_btc(p["amountSats"]) |> Decimal.negate()

      case Enum.find(txs, &(&1["category"] == "send" and &1["address"] == to and Decimal.equal?(&1["amount"], amount))) do
        nil ->
          :not_done

        tx ->
          {:ok,
           %{
             "txid" => tx["txid"],
             "to" => to,
             "amountSats" => p["amountSats"],
             "refs" => %{p["as"] => tx["txid"]},
             "recovered" => true
           }}
      end
    else
      _ -> :unknown
    end
  end

  defp destination(%{"to" => to}, _ctx) when is_binary(to), do: {:ok, to}
  defp destination(%{"toRef" => ref}, ctx), do: Context.ref(ctx, ref)
end

defmodule SatOps.Experiments.Actions.Bitcoin.WaitConfirmations do
  use SatOps.Experiments.Actions.Base,
    name: "bitcoin.wait_confirmations",
    idempotency: :natural,
    capabilities: ["bitcoin.rpc"]

  @impl true
  def validate(p) do
    with :ok <- str(p, "transactionRef"), do: int(p, "confirmations", 1, 100)
  end

  @impl true
  def run(p, ctx) do
    with {:ok, txid} <- Context.ref(ctx, p["transactionRef"]) do
      deadline = System.monotonic_time(:millisecond) + (p["timeoutMs"] || 60_000)
      poll(ctx, txid, p["confirmations"], deadline, 1)
    end
  end

  defp poll(ctx, txid, wanted, deadline, attempt) do
    tx = SatOps.Blockchain.get_transaction(ctx.env.id, txid)
    confs = SatOps.Blockchain.confirmations(ctx.env.id, tx)

    cond do
      confs >= wanted ->
        {:ok, %{"txid" => txid, "confirmations" => confs}}

      System.monotonic_time(:millisecond) > deadline ->
        {:error, "transaction #{txid} reached #{confs}/#{wanted} confirmations before timeout"}

      true ->
        Process.sleep(SatOps.Backoff.delay(attempt, base_ms: 250, max_ms: 2_000, jitter: 0.1))
        poll(ctx, txid, wanted, deadline, attempt + 1)
    end
  end
end

defmodule SatOps.Experiments.Actions.Bitcoin.DisconnectPeer do
  use SatOps.Experiments.Actions.Base,
    name: "bitcoin.disconnect_peer",
    idempotency: :natural,
    capabilities: ["bitcoin.multi_node"]

  @impl true
  def validate(p), do: str(p, "node")

  @impl true
  def run(p, ctx) do
    with {:ok, rpc} <- Context.rpc(ctx, p["node"]),
         {:ok, _} <- RPC.call(rpc, "setnetworkactive", [false]) do
      {:ok, %{"node" => p["node"], "networkActive" => false}}
    else
      {:error, r} -> {:error, rpc_error(r)}
    end
  end
end

defmodule SatOps.Experiments.Actions.Bitcoin.ConnectPeer do
  use SatOps.Experiments.Actions.Base,
    name: "bitcoin.connect_peer",
    idempotency: :natural,
    capabilities: ["bitcoin.multi_node"]

  @impl true
  def validate(p), do: str(p, "node")

  @impl true
  def run(p, ctx) do
    with {:ok, rpc} <- Context.rpc(ctx, p["node"]),
         {:ok, _} <- RPC.call(rpc, "setnetworkactive", [true]),
         :ok <- wait_peers(rpc, System.monotonic_time(:millisecond) + (p["timeoutMs"] || 30_000), 1) do
      {:ok, %{"node" => p["node"], "networkActive" => true}}
    else
      {:error, r} -> {:error, rpc_error(r)}
    end
  end

  defp wait_peers(rpc, deadline, attempt) do
    case RPC.call(rpc, "getconnectioncount") do
      {:ok, n} when n > 0 ->
        :ok

      _ ->
        if System.monotonic_time(:millisecond) > deadline do
          {:error, "node did not reconnect to peers before timeout"}
        else
          Process.sleep(SatOps.Backoff.delay(attempt, base_ms: 250, max_ms: 2_000, jitter: 0.1))
          wait_peers(rpc, deadline, attempt + 1)
        end
    end
  end
end

defmodule SatOps.Experiments.Actions.Bitcoin.ReorganizeChain do
  use SatOps.Experiments.Actions.Base,
    name: "bitcoin.reorganize_chain",
    idempotency: :unsafe,
    capabilities: ["bitcoin.rpc"]

  alias SatOps.Experiments.Actions.Bitcoin.Helpers

  @impl true
  def validate(p), do: int(p, "depth", 1, 20)

  @impl true
  def run(p, ctx) do
    depth = p["depth"]

    with {:ok, rpc} <- Context.rpc(ctx, p["node"]),
         {:ok, height} <- RPC.call(rpc, "getblockcount"),
         {:ok, old_tip} <- RPC.call(rpc, "getbestblockhash"),
         {:ok, fork_hash} <- RPC.call(rpc, "getblockhash", [height - depth + 1]),
         {:ok, _} <- RPC.call(rpc, "invalidateblock", [fork_hash]),
         {:ok, address} <- Helpers.mining_address(rpc, p["wallet"] || "satlab"),
         {:ok, new_blocks} <- RPC.call(rpc, "generatetoaddress", [depth + (p["extraBlocks"] || 1), address]),
         {:ok, _} <- RPC.call(rpc, "reconsiderblock", [fork_hash]),
         {:ok, new_tip} <- RPC.call(rpc, "getbestblockhash") do
      {:ok,
       %{
         "oldTip" => old_tip,
         "invalidated" => fork_hash,
         "newBlocks" => new_blocks,
         "newTip" => new_tip,
         "depth" => depth
       }}
    else
      {:error, r} -> {:error, rpc_error(r)}
    end
  end
end

defmodule SatOps.Experiments.Actions.Bitcoin.StopNode do
  use SatOps.Experiments.Actions.Base,
    name: "bitcoin.stop_node",
    idempotency: :natural,
    capabilities: ["bitcoin.multi_node"]

  @impl true
  def validate(p), do: str(p, "node")

  @impl true
  def run(p, ctx) do
    with {:ok, rpc} <- Context.rpc(ctx, p["node"]) do
      case RPC.call(rpc, "stop") do
        {:ok, msg} ->
          {:ok, %{"node" => p["node"], "message" => msg, "note" => "the container restart policy brings bitcoind back"}}

        {:error, :timeout} ->
          {:ok, %{"node" => p["node"], "message" => "stop requested"}}

        {:error, r} ->
          {:error, rpc_error(r)}
      end
    end
  end
end
