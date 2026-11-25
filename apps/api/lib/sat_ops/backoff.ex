defmodule SatOps.Backoff do
  def delay(attempt, opts \\ []) when attempt >= 1 do
    base = Keyword.get(opts, :base_ms, 500)
    max = Keyword.get(opts, :max_ms, 30_000)
    jitter = Keyword.get(opts, :jitter, 0.2)
    rand = Keyword.get(opts, :rand, &:rand.uniform/0)
    capped = min(max, base * Integer.pow(2, attempt - 1))
    spread = capped * jitter
    round(capped - spread + 2 * spread * rand.())
  end
end
