defmodule SatOps.Repo do
  use Ecto.Repo, otp_app: :sat_ops, adapter: Ecto.Adapters.Postgres

  @retryable ~w(serialization_failure deadlock_detected lock_not_available)a

  def transact_with_retry(fun, opts \\ []) when is_function(fun, 0) do
    attempts = Keyword.get(opts, :attempts, 3)
    do_transact(fun, attempts, 1)
  end

  defp do_transact(fun, max, attempt) do
    transaction(fun)
  rescue
    error in Postgrex.Error ->
      code = error.postgres && error.postgres.code

      if code in @retryable and attempt < max do
        :telemetry.execute([:sat_ops, :repo, :retry], %{count: 1}, %{code: code})
        Process.sleep(SatOps.Backoff.delay(attempt, base_ms: 20, max_ms: 500))
        do_transact(fun, max, attempt + 1)
      else
        reraise error, __STACKTRACE__
      end
  end
end
