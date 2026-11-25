defmodule SatOps.Integrations.Adapter do
  @callback validate_configuration(map()) :: {:ok, map()} | {:error, [String.t()] | String.t()}
  @callback capabilities() :: [String.t()]
  @callback health_check(SatOps.Integrations.Integration.t(), credentials :: String.t() | nil) ::
              {:ok, map()} | {:error, term()}
end

defmodule SatOps.Integrations.FinancialSource do
  @callback fetch_records(SatOps.Integrations.Integration.t(), credentials :: String.t() | nil, opts :: keyword()) ::
              {:ok, %{records: [map()], watermark: String.t() | nil}} | {:error, term()}
  @callback fetch_balances(SatOps.Integrations.Integration.t(), credentials :: String.t() | nil, opts :: keyword()) ::
              {:ok, %{balances: [map()], watermark: String.t() | nil}} | {:error, term()}
end
