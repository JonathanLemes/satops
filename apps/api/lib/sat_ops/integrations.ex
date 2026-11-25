defmodule SatOps.Integrations do
  import Ecto.Query
  require Logger
  alias SatOps.{Audit, Events, Repo, Secrets}
  alias SatOps.Integrations.{Adapters, Integration}

  @adapters %{
    "bitcoin_core" => Adapters.BitcoinCore,
    "demo_fintech" => Adapters.DemoFintech,
    "generic_rest" => Adapters.GenericRest,
    "csv_import" => Adapters.CsvImport,
    "webhook_receiver" => Adapters.WebhookReceiver,
    "webhook_destination" => Adapters.WebhookDestination,
    "kubernetes" => Adapters.Kubernetes
  }

  def adapter(kind), do: Map.get(@adapters, kind)
  def kinds, do: Map.keys(@adapters) |> Enum.sort()

  def financial_source?(%Integration{kind: kind}),
    do: adapter(kind) |> then(&(&1 && function_exported?(&1, :fetch_records, 3)))

  def list(environment_id, opts \\ []) do
    Integration
    |> where([i], i.environment_id == ^environment_id)
    |> then(fn q -> if opts[:kind], do: where(q, [i], i.kind == ^opts[:kind]), else: q end)
    |> then(fn q -> if opts[:enabled], do: where(q, [i], i.enabled), else: q end)
    |> order_by([i], i.name)
    |> Repo.all()
  end

  def list_all_enabled(kind), do: Repo.all(from i in Integration, where: i.kind == ^kind and i.enabled)

  def get(id), do: Repo.get(Integration, id)
  def get!(id), do: Repo.get!(Integration, id)
  def get_by_name(environment_id, name), do: Repo.get_by(Integration, environment_id: environment_id, name: name)

  def create(attrs, actor) do
    Repo.transaction(fn ->
      case %Integration{} |> Integration.changeset(attrs) |> Repo.insert() do
        {:ok, integration} ->
          Audit.record!(actor, "integration.created",
            resource: integration,
            changes: Map.drop(attrs, [:config, "config"])
          )

          integration

        {:error, cs} ->
          Repo.rollback(cs)
      end
    end)
    |> tap(&notify_supervisor/1)
  end

  def update(%Integration{} = integration, attrs, actor) do
    Repo.transaction(fn ->
      case integration |> Integration.changeset(attrs) |> Repo.update() do
        {:ok, updated} ->
          Audit.record!(actor, "integration.updated", resource: updated, changes: %{fields: Map.keys(attrs)})
          updated

        {:error, cs} ->
          Repo.rollback(cs)
      end
    end)
    |> tap(&notify_supervisor/1)
  rescue
    Ecto.StaleEntryError -> {:error, :stale}
  end

  def upsert(environment_id, name, attrs, actor) do
    case get_by_name(environment_id, name) do
      nil -> create(Map.merge(attrs, %{environment_id: environment_id, name: name}), actor)
      existing -> __MODULE__.update(existing, attrs, actor)
    end
  end

  def delete(%Integration{} = integration, actor) do
    Repo.transaction(fn ->
      Repo.delete!(integration)
      Audit.record!(actor, "integration.deleted", resource: integration)
      integration
    end)
    |> tap(fn _ -> SatOps.Blockchain.NodeSupervisor.stop_node(integration.id) end)
  end

  defp notify_supervisor({:ok, %Integration{kind: "bitcoin_core"} = integration}) do
    SatOps.Blockchain.NodeSupervisor.restart_node(integration)
  end

  defp notify_supervisor(_), do: :ok

  def credentials(%Integration{secret_ref: nil}), do: {:ok, nil}

  def credentials(%Integration{environment_id: env, secret_ref: ref}) do
    Secrets.fetch(env, ref)
  end

  def test_connection(%Integration{} = integration) do
    adapter = adapter(integration.kind)

    result =
      with {:ok, creds} <- credentials(integration) do
        adapter.health_check(integration, creds)
      end

    record_health(integration, result)
    result
  end

  def record_health(%Integration{} = integration, result) do
    now = DateTime.utc_now()

    {status, health, error} =
      case result do
        {:ok, health} -> {"healthy", Map.put(health, "checkedAt", DateTime.to_iso8601(now)), nil}
        {:error, reason} -> {"unavailable", %{"checkedAt" => DateTime.to_iso8601(now)}, format_error(reason)}
      end

    Repo.transaction(fn ->
      current = Repo.one(from i in Integration, where: i.id == ^integration.id, lock: "FOR UPDATE")

      if current do
        from(i in Integration, where: i.id == ^integration.id)
        |> Repo.update_all(set: [status: status, health: health, last_error: error, updated_at: now])

        if error do
          Repo.insert_all("integration_errors", [
            %{integration_id: Ecto.UUID.dump!(integration.id), message: String.slice(error, 0, 2000), occurred_at: now}
          ])
        end

        emit_transition(current, status, error)
      end
    end)

    status
  end

  defp emit_transition(%Integration{status: old} = integration, new, error) when old != new do
    {type, node_type} =
      case new do
        "unavailable" -> {"integration.unavailable", "node.disconnected"}
        "healthy" when old == "unavailable" -> {"integration.recovered", "node.reconnected"}
        _ -> {nil, nil}
      end

    if type do
      event_type = if integration.kind == "bitcoin_core", do: node_type, else: type

      Events.append!(%{
        event_type: event_type,
        environment_id: integration.environment_id,
        aggregate_type: "integration",
        aggregate_id: integration.id,
        payload: %{
          "integration" => integration.name,
          "kind" => integration.kind,
          "from" => old,
          "to" => new,
          "error" => error
        }
      })
    end

    :ok
  end

  defp emit_transition(_, _, _), do: :ok

  def format_error({:rpc, code, msg}), do: "RPC error #{code}: #{msg}"
  def format_error({:http_status, status}), do: "HTTP status #{status}"
  def format_error({:transport, reason}), do: "transport error: #{inspect(reason)}"
  def format_error({:unsafe_network, chain}), do: "node reports chain #{chain}; only regtest is allowed"
  def format_error(reason) when is_binary(reason), do: reason
  def format_error(reason), do: inspect(reason)

  def errors(integration_id, limit \\ 20) do
    Repo.all(
      from e in "integration_errors",
        where: e.integration_id == type(^integration_id, :binary_id),
        order_by: [desc: e.id],
        limit: ^limit,
        select: %{message: e.message, occurred_at: type(e.occurred_at, :utc_datetime_usec)}
    )
  end

  def touch_sync(integration_id, checkpoint \\ nil) do
    set = [last_sync_at: DateTime.utc_now()] ++ if(checkpoint, do: [checkpoint: checkpoint], else: [])
    from(i in Integration, where: i.id == ^integration_id) |> Repo.update_all(set: set)
  end

  def receive_webhook(%Integration{} = integration, headers, raw_body) do
    with {:ok, secret} <- webhook_secret(integration),
         {:ok, delivery_id, timestamp} <-
           verify_signature(headers, raw_body, secret, integration.config["webhookToleranceSeconds"] || 300),
         {:ok, payload} <- Jason.decode(raw_body) do
      Repo.transaction(fn ->
        receipt =
          Repo.insert_all(
            "webhook_receipts",
            [
              %{
                integration_id: Ecto.UUID.dump!(integration.id),
                delivery_id: delivery_id,
                signature_valid: true,
                payload_sha256: Base.encode16(:crypto.hash(:sha256, raw_body), case: :lower),
                received_at: DateTime.utc_now()
              }
            ],
            on_conflict: :nothing,
            conflict_target: [:integration_id, :delivery_id]
          )

        case receipt do
          {0, _} ->
            :duplicate

          {1, _} ->
            records = payload |> Map.get("records", [payload["record"]]) |> Enum.reject(&is_nil/1)
            stored = store_records(integration, Enum.map(records, &Adapters.DemoFintech.normalize/1), "webhook")

            Events.append!(%{
              event_type: "integration.records_received",
              environment_id: integration.environment_id,
              aggregate_type: "integration",
              aggregate_id: integration.id,
              payload: %{"count" => stored, "via" => "webhook", "delivery_id" => delivery_id, "sent_at" => timestamp}
            })

            :accepted
        end
      end)
    end
  end

  defp webhook_secret(integration) do
    case integration.config["webhookSecretRef"] do
      nil -> {:error, :webhook_not_configured}
      ref -> Secrets.fetch(integration.environment_id, ref)
    end
  end

  def verify_signature(headers, body, secret, tolerance) do
    signature = header(headers, "x-satops-signature") || header(headers, "x-demofintech-signature")
    delivery = header(headers, "x-satops-delivery") || header(headers, "x-demofintech-delivery")

    with sig when is_binary(sig) <- signature,
         delivery when is_binary(delivery) and delivery != "" <- delivery,
         %{"t" => t, "v1" => v1} <- parse_signature(sig),
         {ts, ""} <- Integer.parse(t),
         true <- abs(System.system_time(:second) - ts) <= tolerance || {:error, :timestamp_out_of_tolerance},
         expected = :crypto.mac(:hmac, :sha256, secret, "#{t}.#{body}") |> Base.encode16(case: :lower),
         true <- Plug.Crypto.secure_compare(expected, String.downcase(v1)) || {:error, :invalid_signature} do
      {:ok, delivery, ts}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_signature}
    end
  end

  defp parse_signature(sig) do
    sig
    |> String.split(",")
    |> Enum.map(&String.split(&1, "=", parts: 2))
    |> Enum.filter(&match?([_, _], &1))
    |> Map.new(fn [k, v] -> {String.trim(k), String.trim(v)} end)
  end

  defp header(headers, name) do
    Enum.find_value(headers, fn {k, v} -> if String.downcase(k) == name, do: v end)
  end

  def store_records(%Integration{} = integration, records, via) do
    now = DateTime.utc_now()

    rows =
      records
      |> Enum.filter(&(is_binary(&1["source_record_id"]) and is_integer(&1["amount_sats"])))
      |> Enum.map(fn r ->
        %{
          environment_id: Ecto.UUID.dump!(integration.environment_id),
          integration_id: Ecto.UUID.dump!(integration.id),
          source_record_id: r["source_record_id"],
          kind: r["kind"] || "unknown",
          account_ref: r["account_ref"],
          asset: r["asset"] || "BTC",
          amount_sats: r["amount_sats"],
          txid: r["txid"],
          vout: r["vout"],
          status: r["status"] || "unknown",
          occurred_at: parse_time(r["occurred_at"]),
          raw: r,
          received_via: via,
          inserted_at: now,
          updated_at: now
        }
      end)

    {count, _} =
      Repo.insert_all("external_records", rows,
        on_conflict:
          {:replace, [:kind, :account_ref, :amount_sats, :txid, :vout, :status, :occurred_at, :raw, :updated_at]},
        conflict_target: [:integration_id, :source_record_id]
      )

    count
  end

  defp parse_time(nil), do: nil
  defp parse_time(%DateTime{} = dt), do: dt

  defp parse_time(s) when is_binary(s) do
    case DateTime.from_iso8601(s) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
end
