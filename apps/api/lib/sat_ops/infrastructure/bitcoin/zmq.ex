defmodule SatOps.Infrastructure.Bitcoin.ZMQ do
  def parse_sequence_message(["sequence", <<hash::binary-32, label, rest::binary>>, <<seq::little-unsigned-32>>]) do
    hash_hex = hash |> Base.encode16(case: :lower)

    mempool_seq =
      case rest do
        <<n::little-unsigned-64>> -> n
        _ -> nil
      end

    kind =
      case label do
        ?C -> :block_connected
        ?D -> :block_disconnected
        ?A -> :tx_added
        ?R -> :tx_removed
        _ -> :unknown
      end

    {:ok, %{topic: "sequence", kind: kind, hash: hash_hex, mempool_sequence: mempool_seq, zmq_seq: seq}}
  end

  def parse_sequence_message([topic, body, <<seq::little-unsigned-32>>]) when topic in ["hashblock", "hashtx"] do
    {:ok, %{topic: topic, kind: String.to_atom(topic), hash: Base.encode16(body, case: :lower), zmq_seq: seq}}
  end

  def parse_sequence_message([topic, _body, <<seq::little-unsigned-32>>]) when topic in ["rawblock", "rawtx"] do
    {:ok, %{topic: topic, kind: String.to_atom(topic), zmq_seq: seq}}
  end

  def parse_sequence_message(_), do: {:error, :malformed}

  def track_sequence(nil, seq), do: {:ok, seq}
  def track_sequence(last, seq) when seq == rem(last + 1, 4_294_967_296), do: {:ok, seq}
  def track_sequence(last, seq) when seq == last, do: {:duplicate, last}
  def track_sequence(last, seq) when seq < last and last - seq < 1_000, do: {:duplicate, last}
  def track_sequence(last, seq), do: {:gap, seq, gap_size(last, seq)}

  defp gap_size(last, seq) when seq > last, do: seq - last - 1
  defp gap_size(last, seq), do: 4_294_967_296 - last - 1 + seq
end
