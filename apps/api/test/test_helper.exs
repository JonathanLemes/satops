exclude = if System.get_env("BITCOIN_TEST_RPC_URL"), do: [], else: [:bitcoin]
ExUnit.start(exclude: exclude, capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(SatOps.Repo, :manual)
