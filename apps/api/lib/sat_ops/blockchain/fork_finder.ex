defmodule SatOps.Blockchain.ForkFinder do
  def find(local_chain_desc, in_remote_best_chain?, max_depth \\ 1_000) do
    local_chain_desc
    |> Enum.take(max_depth)
    |> Enum.reduce_while({:disconnect, []}, fn {height, hash}, {:disconnect, acc} ->
      case in_remote_best_chain?.(hash) do
        {:ok, true} -> {:halt, {:ancestor, {height, hash}, Enum.reverse(acc)}}
        {:ok, false} -> {:cont, {:disconnect, [{height, hash} | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ancestor, ancestor, disconnected_desc} -> {:ok, ancestor, disconnected_desc}
      {:disconnect, acc} when length(acc) >= max_depth -> {:error, :reorg_too_deep}
      {:disconnect, acc} -> {:ok, nil, Enum.reverse(acc)}
      {:error, reason} -> {:error, reason}
    end
  end

  def select_reference(observations) do
    observations
    |> Enum.filter(&(&1.reachable and &1.chain == "regtest" and not (&1.initial_block_download || false)))
    |> Enum.sort_by(fn o -> {Decimal.to_integer(o.chainwork || Decimal.new(0)), -(o.priority || 100)} end, :desc)
    |> List.first()
  end

  def divergent?(observations) do
    observations
    |> Enum.filter(& &1.reachable)
    |> Enum.map(& &1.best_hash)
    |> Enum.uniq()
    |> length()
    |> Kernel.>(1)
  end
end
