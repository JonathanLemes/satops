defmodule SatOps.Integrations.Adapters.GenericRest do
  @behaviour SatOps.Integrations.Adapter
  @behaviour SatOps.Integrations.FinancialSource
  alias SatOps.Integrations.ConfigValidation, as: V
  alias SatOps.Integrations.Http

  @fields ~w(source_record_id kind account_ref asset amount_sats txid vout status occurred_at)

  @impl true
  def capabilities, do: ["financial.records", "financial.balances"]

  @impl true
  def validate_configuration(config) do
    config = Map.new(config, fn {k, v} -> {to_string(k), v} end)
    mapping = config["fieldMapping"] || %{}

    with :ok <-
           V.run(config, [
             {"baseUrl", &V.required_url/1},
             {"recordsPath", &V.required_string/1},
             {"balancesPath", &V.optional_string/1},
             {"timeoutMs", V.duration_ms(100, 60_000)}
           ]),
         :ok <- validate_mapping(mapping) do
      {:ok,
       %{
         "baseUrl" => String.trim_trailing(config["baseUrl"], "/"),
         "recordsPath" => config["recordsPath"],
         "balancesPath" => config["balancesPath"],
         "recordsKey" => config["recordsKey"] || "records",
         "fieldMapping" => mapping,
         "timeoutMs" => config["timeoutMs"] || 5_000,
         "authHeader" => config["authHeader"] || "authorization"
       }}
    end
  end

  defp validate_mapping(mapping) when is_map(mapping) do
    bad = Map.keys(mapping) -- @fields
    if bad == [], do: :ok, else: {:error, ["fieldMapping: unsupported target fields #{Enum.join(bad, ", ")}"]}
  end

  defp validate_mapping(_), do: {:error, ["fieldMapping: must be an object"]}

  defp headers(integration, token) do
    if token, do: [{integration.config["authHeader"], "Bearer " <> token}], else: []
  end

  @impl true
  def health_check(integration, token) do
    with {:ok, _} <-
           Http.request(:get, integration.config["baseUrl"] <> integration.config["recordsPath"],
             headers: headers(integration, token),
             max_attempts: 1,
             timeout: integration.config["timeoutMs"]
           ) do
      {:ok, %{"status" => "ok"}}
    end
  end

  @impl true
  def fetch_records(integration, token, _opts) do
    with {:ok, %{body: body}} when is_map(body) <-
           Http.request(:get, integration.config["baseUrl"] <> integration.config["recordsPath"],
             headers: headers(integration, token),
             timeout: integration.config["timeoutMs"]
           ),
         records when is_list(records) <- Map.get(body, integration.config["recordsKey"]) do
      {:ok,
       %{records: Enum.map(records, &map_record(&1, integration.config["fieldMapping"])), watermark: body["watermark"]}}
    else
      {:error, _} = error -> error
      _ -> {:error, :invalid_response}
    end
  end

  @impl true
  def fetch_balances(%{config: %{"balancesPath" => nil}}, _token, _opts), do: {:error, :not_supported}

  def fetch_balances(integration, token, _opts) do
    with {:ok, %{body: %{"balances" => balances} = body}} <-
           Http.request(:get, integration.config["baseUrl"] <> integration.config["balancesPath"],
             headers: headers(integration, token),
             timeout: integration.config["timeoutMs"]
           ) do
      {:ok, %{balances: balances, watermark: body["asOf"]}}
    else
      {:ok, _} -> {:error, :invalid_response}
      error -> error
    end
  end

  def map_record(raw, mapping) do
    Map.new(@fields, fn field -> {field, Map.get(raw, Map.get(mapping, field, field))} end)
    |> Map.update!("source_record_id", &(&1 && to_string(&1)))
  end
end
