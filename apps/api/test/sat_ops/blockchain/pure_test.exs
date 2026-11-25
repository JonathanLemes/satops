defmodule SatOps.Blockchain.PureTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias SatOps.Blockchain.{ForkFinder, TxState}
  alias SatOps.Infrastructure.Bitcoin.ZMQ

  describe "ForkFinder.find/3" do
    test "returns the common ancestor and blocks to disconnect, tip first" do
      local = [{5, "e"}, {4, "d"}, {3, "c"}, {2, "b"}]
      remote = MapSet.new(["a", "b", "c"])
      assert {:ok, {3, "c"}, [{5, "e"}, {4, "d"}]} = ForkFinder.find(local, &{:ok, MapSet.member?(remote, &1)})
    end

    test "no disconnection when the local tip is still in the remote chain" do
      assert {:ok, {2, "b"}, []} = ForkFinder.find([{2, "b"}, {1, "a"}], fn _ -> {:ok, true} end)
    end

    test "propagates RPC errors and refuses arbitrarily deep reorgs" do
      assert {:error, :timeout} = ForkFinder.find([{1, "a"}], fn _ -> {:error, :timeout} end)
      chain = for h <- 10..1//-1, do: {h, "h#{h}"}
      assert {:error, :reorg_too_deep} = ForkFinder.find(chain, fn _ -> {:ok, false} end, 5)
    end
  end

  describe "reference selection" do
    test "prefers most accumulated work, not height, and ignores unsafe nodes" do
      obs = [
        %{reachable: true, chain: "regtest", chainwork: Decimal.new(100), height: 50, priority: 100, name: "tall"},
        %{reachable: true, chain: "regtest", chainwork: Decimal.new(200), height: 40, priority: 100, name: "heavy"},
        %{reachable: true, chain: "main", chainwork: Decimal.new(999), height: 99, priority: 1, name: "mainnet"},
        %{reachable: false, chain: "regtest", chainwork: Decimal.new(500), height: 10, priority: 1, name: "down"}
      ]

      assert ForkFinder.select_reference(obs).name == "heavy"
    end

    test "a fresh regtest chain still in initial block download is used when nothing better exists" do
      obs = [
        %{
          reachable: true,
          chain: "regtest",
          chainwork: Decimal.new(2),
          initial_block_download: true,
          priority: 100,
          name: "fresh"
        }
      ]

      assert ForkFinder.select_reference(obs).name == "fresh"
    end

    test "divergence is reported when reachable nodes disagree" do
      assert ForkFinder.divergent?([%{reachable: true, best_hash: "a"}, %{reachable: true, best_hash: "b"}])
      refute ForkFinder.divergent?([%{reachable: true, best_hash: "a"}, %{reachable: false, best_hash: "b"}])
    end
  end

  describe "TxState" do
    test "confirmed can only become unconfirmed" do
      assert {:ok, "unconfirmed"} = TxState.transition("confirmed", "unconfirmed")
      assert {:error, _} = TxState.transition("confirmed", "replaced")
      assert :noop = TxState.transition("pending", "pending")
    end

    test "confirmation count" do
      assert TxState.confirmations(105, 103) == 3
      assert TxState.confirmations(105, nil) == 0
      assert TxState.confirmations(100, 103) == 0
    end
  end

  describe "ZMQ sequence tracking" do
    test "detects duplicates and gaps, including wraparound" do
      assert {:ok, 5} = ZMQ.track_sequence(4, 5)
      assert {:duplicate, 5} = ZMQ.track_sequence(5, 5)
      assert {:gap, 9, 3} = ZMQ.track_sequence(5, 9)
      assert {:ok, 0} = ZMQ.track_sequence(4_294_967_295, 0)
      assert {:gap, 1, 1} = ZMQ.track_sequence(4_294_967_295, 1)
    end

    test "parses sequence notifications" do
      hash = :binary.copy(<<0xAB>>, 32)

      assert {:ok, %{kind: :block_connected, zmq_seq: 7}} =
               ZMQ.parse_sequence_message(["sequence", hash <> "C", <<7::little-32>>])

      assert {:ok, %{kind: :tx_added, mempool_sequence: 3}} =
               ZMQ.parse_sequence_message(["sequence", hash <> "A" <> <<3::little-64>>, <<8::little-32>>])

      assert {:error, :malformed} = ZMQ.parse_sequence_message(["garbage"])
    end
  end

  test "satoshi conversion never uses floats" do
    alias SatOps.Infrastructure.Bitcoin.RPC
    assert RPC.btc_to_sats(Decimal.new("0.00000001")) == 1
    assert RPC.btc_to_sats(Decimal.new("20999999.97690000")) == 2_099_999_997_690_000
    assert Decimal.equal?(RPC.sats_to_btc(12_345), Decimal.new("0.00012345"))
  end
end
