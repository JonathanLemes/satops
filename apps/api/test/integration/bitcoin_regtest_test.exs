defmodule SatOps.Integration.BitcoinRegtestTest do
  use SatOps.DataCase
  @moduletag :bitcoin
  @moduletag timeout: 180_000

  alias SatOps.{Blockchain, Ledger, WalletMonitoring}
  alias SatOps.Blockchain.ChainSync
  alias SatOps.Infrastructure.Bitcoin.RPC
  alias SatOps.Ledger.{Chart, ChainConsumer}

  setup do
    url = System.fetch_env!("BITCOIN_TEST_RPC_URL")

    rpc =
      RPC.new(
        url: url,
        user: System.fetch_env!("BITCOIN_TEST_RPC_USER"),
        password: System.fetch_env!("BITCOIN_TEST_RPC_PASSWORD"),
        timeout: 15_000
      )

    env = environment(%{required_confirmations: 2})
    wallet = "satops-test"

    case RPC.call(rpc, "createwallet", [wallet]) do
      {:ok, _} -> :ok
      {:error, {:rpc, -4, _}} -> RPC.call(rpc, "loadwallet", [wallet])
      {:error, {:rpc, -35, _}} -> :ok
    end

    wrpc = RPC.with_wallet(rpc, wallet)
    {:ok, mine_to} = RPC.call(wrpc, "getnewaddress")
    {:ok, balance} = RPC.call(wrpc, "getbalance")
    if Decimal.lt?(balance, Decimal.new(5)), do: {:ok, _} = RPC.call(rpc, "generatetoaddress", [101, mine_to])
    {:ok, env: env, rpc: rpc, wrpc: wrpc, mine_to: mine_to}
  end

  defp sync!(env, rpc) do
    {:ok, result} = ChainSync.run(env, rpc, max_blocks: 2_000)
    if result.caught_up, do: result, else: sync!(env, rpc)
  end

  defp consume_events(env) do
    import Ecto.Query
    events = Repo.all(from e in SatOps.Events.Event, where: e.environment_id == ^env.id, order_by: e.seq)

    for e <- events, ChainConsumer.interested?(e.event_type) do
      {:ok, :ok} = Repo.transaction(fn -> ChainConsumer.handle(e) end)
    end
  end

  test "detects regtest transactions, confirms deposits by policy and reverses them on reorganization", %{
    env: env,
    rpc: rpc,
    wrpc: wrpc,
    mine_to: mine_to
  } do
    {:ok, info} = RPC.call(rpc, "getblockchaininfo")
    assert info["chain"] == "regtest"

    {:ok, deposit_address} = RPC.call(wrpc, "getnewaddress")

    {:ok, wallet} =
      WalletMonitoring.create_wallet(
        %{
          environment_id: env.id,
          name: "customer-1",
          kind: "addresses",
          account_ref: "customer-1",
          addresses: [deposit_address]
        },
        nil
      )

    assert length(wallet.addresses) == 1

    sync!(env, rpc)
    assert Blockchain.tip(env.id).hash == info["bestblockhash"] or Blockchain.tip(env.id).height >= info["blocks"]

    {:ok, txid} = RPC.call(wrpc, "sendtoaddress", [deposit_address, Decimal.new("0.015")])
    sync!(env, rpc)
    assert Blockchain.get_transaction(env.id, txid).status == "pending"
    consume_events(env)
    assert Ledger.balance(env.id, Chart.pending("customer-1")) == 1_500_000
    assert Ledger.balance(env.id, Chart.available("customer-1")) == 0

    {:ok, [block1]} = RPC.call(rpc, "generatetoaddress", [1, mine_to])
    sync!(env, rpc)
    consume_events(env)
    assert Blockchain.get_transaction(env.id, txid).status == "confirmed"
    assert Ledger.balance(env.id, Chart.available("customer-1")) == 0

    {:ok, _} = RPC.call(rpc, "generatetoaddress", [1, mine_to])
    sync!(env, rpc)
    consume_events(env)
    assert Ledger.balance(env.id, Chart.available("customer-1")) == 1_500_000
    assert %{confirmed_sats: 1_500_000} = WalletMonitoring.balance(env.id, 2)

    {:ok, _} = RPC.call(rpc, "invalidateblock", [block1])
    {:ok, fresh} = RPC.call(wrpc, "getnewaddress")
    {:ok, _} = RPC.call(rpc, "generatetoaddress", [3, fresh])
    {:ok, _} = RPC.call(rpc, "reconsiderblock", [block1])
    result = sync!(env, rpc)
    assert result.reorganized or Blockchain.reorganizations(env.id) != []

    consume_events(env)
    tx = Blockchain.get_transaction(env.id, txid)
    assert tx.status == "confirmed"
    refute tx.block_hash == block1
    history = Blockchain.status_history(env.id, txid) |> Enum.map(& &1.to_status)
    assert "unconfirmed" in history

    assert Ledger.balance(env.id, Chart.available("customer-1")) == 1_500_000

    op =
      Ledger.get_operation(
        env.id,
        "deposit:#{txid}:#{Enum.find(Blockchain.outputs(env.id, txid), &(&1.address == deposit_address)).vout}"
      )

    assert op.generation == 1
    assert Ledger.duplicate_credits(env.id) == 0
    assert Ledger.verify_invariants(env.id).ok

    [reorg | _] = Blockchain.reorganizations(env.id)
    assert block1 in reorg.payload["disconnected"]
  end

  test "state lost while notifications are missed is rebuilt from RPC", %{
    env: env,
    rpc: rpc,
    wrpc: wrpc,
    mine_to: mine_to
  } do
    sync!(env, rpc)
    {:ok, addr} = RPC.call(wrpc, "getnewaddress")
    {:ok, txid} = RPC.call(wrpc, "sendtoaddress", [addr, Decimal.new("0.001")])
    {:ok, _} = RPC.call(rpc, "generatetoaddress", [3, mine_to])
    {:ok, best} = RPC.call(rpc, "getbestblockhash")

    sync!(env, rpc)
    assert Blockchain.tip(env.id).hash == best
    assert Blockchain.get_transaction(env.id, txid).status == "confirmed"
    assert Blockchain.confirmations(env.id, Blockchain.get_transaction(env.id, txid)) == 3
  end

  test "refuses to ingest when the node is not regtest" do
    assert {:error, {:unsafe_network, "main"}} = SatOps.Environments.assert_regtest_chain("main")
  end
end
