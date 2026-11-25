defmodule SatOps.Integrations.Adapters.DemoFintech do
  @behaviour SatOps.Integrations.Adapter
  @behaviour SatOps.Integrations.FinancialSource
  alias SatOps.Integrations.ConfigValidation, as: V
  alias SatOps.Integrations.Http

  @impl true
  def capabilities, do: ["financial.records", "financial.balances", "webhooks.inbound", "fault_injection"]

  @impl true
  def validate_configuration(config) do
    config = Map.new(config, fn {k, v} -> {to_string(k), v} end)

    with :ok <- V.run(config, [{"baseUrl", &V.required_url/1}, {"timeoutMs", V.duration_ms(100, 60_000)}]) do
      {:ok,
       %{
         "baseUrl" => String.trim_trailing(config["baseUrl"], "/"),
         "timeoutMs" => config["timeoutMs"] || 5_000,
         "webhookSecretRef" => config["webhookSecretRef"],
         "webhookToleranceSeconds" => config["webhookToleranceSeconds"] || 300
       }}
    end
  end

  defp headers(token), do: [{"authorization", "Bearer #{token}"}, {"accept", "application/json"}]

  @impl true
  def health_check(integration, token) do
    started = System.monotonic_time(:millisecond)

    with {:ok, %{body: body}} <-
           Http.request(:get, integration.config["baseUrl"] <> "/health",
             headers: headers(token),
             timeout: integration.config["timeoutMs"],
             max_attempts: 1
           ) do
      {:ok,
       %{
         "status" => body["status"],
         "latencyMs" => System.monotonic_time(:millisecond) - started,
         "faults" => body["faults"]
       }}
    end
  end

  @impl true
  def fetch_records(integration, token, _opts) do
    with {:ok, %{body: %{"records" => records} = body}} <-
           Http.request(:get, integration.config["baseUrl"] <> "/v1/records",
             headers: headers(token),
             timeout: integration.config["timeoutMs"]
           ) do
      {:ok, %{records: Enum.map(records, &normalize/1), watermark: body["watermark"]}}
    else
      {:ok, _} -> {:error, :invalid_response}
      error -> error
    end
  end

  @impl true
  def fetch_balances(integration, token, _opts) do
    with {:ok, %{body: %{"balances" => balances} = body}} <-
           Http.request(:get, integration.config["baseUrl"] <> "/v1/balances",
             headers: headers(token),
             timeout: integration.config["timeoutMs"]
           ) do
      {:ok,
       %{
         balances:
           Enum.map(balances, fn b ->
             %{
               "account_ref" => b["customerId"],
               "available_sats" => b["availableSats"],
               "pending_sats" => b["pendingSats"],
               "reserved_sats" => b["reservedSats"]
             }
           end),
         watermark: body["asOf"]
       }}
    else
      {:ok, _} -> {:error, :invalid_response}
      error -> error
    end
  end

  def set_fault(integration, token, mode, enabled) do
    Http.request(:post, integration.config["baseUrl"] <> "/v1/faults",
      headers: headers(token),
      json: %{mode: mode, enabled: enabled},
      timeout: integration.config["timeoutMs"],
      max_attempts: 1
    )
  end

  def call(integration, token, method, path, body \\ nil) do
    Http.request(method, integration.config["baseUrl"] <> path,
      headers: headers(token),
      json: body,
      timeout: integration.config["timeoutMs"],
      max_attempts: 1
    )
  end

  def normalize(r) do
    %{
      "source_record_id" => to_string(r["id"]),
      "kind" => r["kind"],
      "account_ref" => r["customerId"],
      "asset" => r["asset"] || "BTC",
      "amount_sats" => r["amountSats"],
      "txid" => r["txid"],
      "vout" => r["vout"],
      "status" => r["status"],
      "occurred_at" => r["occurredAt"]
    }
  end
end
