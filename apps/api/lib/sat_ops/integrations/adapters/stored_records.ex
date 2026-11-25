defmodule SatOps.Integrations.Adapters.StoredRecords do
  import Ecto.Query
  alias SatOps.Repo

  def fetch(integration) do
    rows =
      Repo.all(
        from r in "external_records",
          where: r.integration_id == type(^integration.id, :binary_id),
          select: %{
            source_record_id: r.source_record_id,
            kind: r.kind,
            account_ref: r.account_ref,
            asset: r.asset,
            amount_sats: r.amount_sats,
            txid: r.txid,
            vout: r.vout,
            status: r.status,
            occurred_at: r.occurred_at,
            updated_at: r.updated_at
          }
      )

    watermark = rows |> Enum.map(& &1.updated_at) |> Enum.max(DateTime, fn -> nil end)
    records = Enum.map(rows, fn r -> r |> Map.delete(:updated_at) |> Map.new(fn {k, v} -> {to_string(k), v} end) end)
    {:ok, %{records: records, watermark: watermark && DateTime.to_iso8601(watermark)}}
  end
end

defmodule SatOps.Integrations.Adapters.CsvImport do
  @behaviour SatOps.Integrations.Adapter
  @behaviour SatOps.Integrations.FinancialSource

  @impl true
  def capabilities, do: ["financial.records", "csv.upload"]
  @impl true
  def validate_configuration(config),
    do: {:ok, Map.take(Map.new(config, fn {k, v} -> {to_string(k), v} end), ["description"])}

  @impl true
  def health_check(_integration, _), do: {:ok, %{"status" => "ok"}}
  @impl true
  def fetch_records(integration, _, _), do: SatOps.Integrations.Adapters.StoredRecords.fetch(integration)
  @impl true
  def fetch_balances(_, _, _), do: {:error, :not_supported}
end

defmodule SatOps.Integrations.Adapters.WebhookReceiver do
  @behaviour SatOps.Integrations.Adapter
  @behaviour SatOps.Integrations.FinancialSource

  @impl true
  def capabilities, do: ["financial.records", "webhooks.inbound"]
  @impl true
  def validate_configuration(config) do
    config = Map.new(config, fn {k, v} -> {to_string(k), v} end)

    {:ok,
     %{
       "webhookSecretRef" => config["webhookSecretRef"],
       "webhookToleranceSeconds" => config["webhookToleranceSeconds"] || 300
     }}
  end

  @impl true
  def health_check(_integration, _), do: {:ok, %{"status" => "ok"}}
  @impl true
  def fetch_records(integration, _, _), do: SatOps.Integrations.Adapters.StoredRecords.fetch(integration)
  @impl true
  def fetch_balances(_, _, _), do: {:error, :not_supported}
end

defmodule SatOps.Integrations.Adapters.WebhookDestination do
  @behaviour SatOps.Integrations.Adapter
  alias SatOps.Integrations.ConfigValidation, as: V

  @impl true
  def capabilities, do: ["webhooks.outbound"]

  @impl true
  def validate_configuration(config) do
    config = Map.new(config, fn {k, v} -> {to_string(k), v} end)

    with :ok <- V.run(config, [{"url", &V.required_url/1}, {"timeoutMs", V.duration_ms(100, 30_000)}]) do
      {:ok,
       %{
         "url" => config["url"],
         "timeoutMs" => config["timeoutMs"] || 5_000,
         "maxAttempts" => min(config["maxAttempts"] || 8, 20)
       }}
    end
  end

  @impl true
  def health_check(integration, _) do
    case SatOps.Integrations.UrlPolicy.validate_url(integration.config["url"]) do
      {:ok, _} -> {:ok, %{"status" => "configured"}}
      {:error, reason} -> {:error, reason}
    end
  end
end
