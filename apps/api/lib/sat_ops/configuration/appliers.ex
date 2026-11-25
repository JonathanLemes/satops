defmodule SatOps.Configuration.Appliers do
  alias SatOps.{Alerts, Dashboards, Environments, Experiments, Integrations}
  alias SatOps.Integrations.ConfigValidation

  def apply(%{"kind" => "Environment", "metadata" => meta, "spec" => spec}, _resource) do
    attrs = %{
      slug: meta["name"],
      name: spec["displayName"] || meta["name"],
      kind: spec["kind"] || "persistent",
      network: "regtest",
      required_confirmations: get_in(spec, ["ledger", "confirmationPolicy", "requiredConfirmations"]) || 3,
      settings: Map.drop(spec, ["displayName", "kind"])
    }

    with {:ok, env} <- Environments.upsert_by_slug(attrs, nil) do
      {:ok, %{"environmentId" => env.id, "status" => env.status, "requiredConfirmations" => env.required_confirmations}}
    end
  end

  def apply(%{"kind" => "BitcoinIntegration", "metadata" => meta, "spec" => spec}, _resource) do
    with {:ok, env} <- env(spec) do
      attrs = %{
        kind: "bitcoin_core",
        secret_ref: spec["rpc"]["secretRef"],
        enabled: Map.get(spec, "enabled", true),
        retry: spec["retry"] || %{},
        config: %{
          "host" => spec["rpc"]["host"],
          "port" => spec["rpc"]["port"],
          "wallet" => spec["rpc"]["wallet"],
          "zmqEnabled" => get_in(spec, ["zmq", "enabled"]) || false,
          "zmqEndpoint" => get_in(spec, ["zmq", "endpoint"]),
          "reconcileIntervalMs" =>
            ConfigValidation.parse_duration(get_in(spec, ["monitoring", "reconcileInterval"]), 30_000),
          "timeoutMs" => ConfigValidation.parse_duration(get_in(spec, ["monitoring", "timeout"]), 5_000),
          "priority" => spec["priority"] || 100
        }
      }

      upsert_integration(env, meta["name"], attrs)
    end
  end

  def apply(%{"kind" => "FinancialIntegration", "metadata" => meta, "spec" => spec}, _resource) do
    with {:ok, env} <- env(spec) do
      conn = spec["connection"] || %{}
      mapping = spec["mapping"] || %{}

      config =
        %{
          "baseUrl" => conn["baseUrl"],
          "url" => conn["url"],
          "timeoutMs" => ConfigValidation.parse_duration(conn["timeout"], 5_000),
          "webhookSecretRef" => get_in(spec, ["webhook", "secretRef"]),
          "webhookToleranceSeconds" => get_in(spec, ["webhook", "toleranceSeconds"]),
          "recordsPath" => mapping["recordsPath"],
          "balancesPath" => mapping["balancesPath"],
          "recordsKey" => mapping["recordsKey"],
          "fieldMapping" => mapping["fields"],
          "maxAttempts" => get_in(spec, ["retry", "maxAttempts"])
        }
        |> Map.reject(fn {_, v} -> is_nil(v) end)

      upsert_integration(env, meta["name"], %{
        kind: spec["type"],
        secret_ref: spec["secretRef"],
        enabled: Map.get(spec, "enabled", true),
        config: config
      })
    end
  end

  def apply(%{"kind" => "BitcoinNetwork", "spec" => spec}, _resource) do
    with {:ok, env} <- env(spec) do
      {:ok, Map.put(observe_network(env, spec), "environmentId", env.id)}
    end
  end

  def apply(%{"kind" => "ReconciliationPolicy", "spec" => spec}, _resource) do
    with {:ok, env} <- env(spec) do
      {:ok, %{"environmentId" => env.id, "sources" => spec["sources"], "requiredSources" => spec["requiredSources"]}}
    end
  end

  def apply(%{"kind" => "Experiment", "metadata" => meta, "spec" => spec}, resource) do
    with {:ok, scenario} <-
           Experiments.upsert_scenario(
             meta["name"],
             resource.desired_revision,
             spec,
             SatOps.Configuration.Yaml.encode(%{"spec" => spec})
           ) do
      {:ok, %{"scenarioId" => scenario.id, "version" => scenario.version}}
    end
  end

  def apply(%{"kind" => "Dashboard", "metadata" => meta, "spec" => spec}, _resource) do
    with {:ok, dashboard} <- Dashboards.upsert_shared(meta["name"], spec, nil) do
      {:ok, %{"dashboardId" => dashboard.id}}
    end
  end

  def apply(%{"kind" => "AlertPolicy", "metadata" => meta, "spec" => spec}, _resource) do
    with {:ok, env} <- env(spec) do
      attrs = %{
        "name" => meta["name"],
        "event_types" => spec["events"],
        "severity" => spec["severity"] || "warning",
        "cooldown_seconds" => div(ConfigValidation.parse_duration(spec["cooldown"], 300_000), 1000),
        "destinations" => spec["destinations"] || [%{"type" => "internal"}],
        "enabled" => Map.get(spec, "enabled", true)
      }

      with {:ok, policy} <- Alerts.upsert_policy(env.id, attrs, nil) do
        {:ok, %{"environmentId" => env.id, "policyId" => policy.id}}
      end
    end
  end

  defp env(spec) do
    case Environments.get_by_slug(spec["environmentRef"]) do
      nil -> {:error, "environment #{spec["environmentRef"]} not found"}
      env -> {:ok, env}
    end
  end

  defp upsert_integration(env, name, attrs) do
    with {:ok, integration} <- Integrations.upsert(env.id, name, attrs, nil) do
      {:ok, %{"environmentId" => env.id, "integrationId" => integration.id, "status" => integration.status}}
    end
  end

  def observe(%{"kind" => kind, "metadata" => meta, "spec" => spec})
      when kind in ["BitcoinIntegration", "FinancialIntegration"] do
    with %{} = env <- Environments.get_by_slug(spec["environmentRef"]),
         %{} = i <- Integrations.get_by_name(env.id, meta["name"]) do
      %{
        "environmentId" => env.id,
        "integrationId" => i.id,
        "status" => i.status,
        "lastError" => i.last_error,
        "lastSyncAt" => i.last_sync_at && DateTime.to_iso8601(i.last_sync_at)
      }
    else
      _ -> %{"status" => "missing"}
    end
  end

  def observe(%{"kind" => "BitcoinNetwork", "spec" => spec}) do
    case Environments.get_by_slug(spec["environmentRef"]) do
      nil -> %{"status" => "missing"}
      env -> Map.put(observe_network(env, spec), "environmentId", env.id)
    end
  end

  def observe(%{"kind" => "Environment", "metadata" => meta}) do
    case Environments.get_by_slug(meta["name"]) do
      nil -> %{"status" => "missing"}
      env -> %{"environmentId" => env.id, "status" => env.status, "requiredConfirmations" => env.required_confirmations}
    end
  end

  def observe(_doc), do: %{"status" => "applied"}

  defp observe_network(env, spec) do
    declared = (spec["nodes"] || []) |> Enum.map(& &1["integrationRef"])
    actual = Integrations.list(env.id, kind: "bitcoin_core") |> Enum.map(& &1.name)
    %{"declaredNodes" => declared, "registeredNodes" => actual, "missingNodes" => declared -- actual}
  end

  def impact(%{"kind" => kind} = doc, current, changes) do
    base =
      case {current, kind} do
        {nil, "Environment"} ->
          ["Creates sandbox environment #{doc["metadata"]["name"]} on an isolated regtest network."]

        {nil, "BitcoinIntegration"} ->
          ["Registers a Bitcoin Core node and starts a supervised monitor for it."]

        {nil, "FinancialIntegration"} ->
          ["Registers an external financial source; credentials are resolved from secret references."]

        {nil, "Experiment"} ->
          ["Publishes a new scenario version; existing runs keep the version they started with."]

        {nil, "AlertPolicy"} ->
          ["Starts evaluating alert rules for the listed events."]

        {nil, _} ->
          ["Creates #{kind} #{doc["metadata"]["name"]}."]

        {_, _} ->
          []
      end

    specific =
      Enum.flat_map(changes, fn
        %{path: "/spec/rpc" <> _} ->
          ["The node monitor restarts with the new RPC connection settings."]

        %{path: "/spec/zmq" <> _} ->
          ["The ZeroMQ subscriber reconnects; missed notifications are recovered by RPC backfill."]

        %{path: "/spec/ledger/confirmationPolicy" <> _} ->
          ["Confirmation policy changes apply to future evaluations; posted journals are never reinterpreted."]

        %{path: "/spec/enabled", new: false} ->
          ["The integration stops being monitored and polled."]

        %{path: "/spec/steps" <> _} ->
          ["A new scenario version is created; previous run reports remain tied to their version."]

        %{path: "/spec/sources" <> _} ->
          ["Future reconciliation runs use the new source set."]

        %{path: "/spec/requiredSources" <> _} ->
          ["Runs become incomplete when any newly required source is unavailable."]

        _ ->
          []
      end)

    Enum.uniq(
      base ++ specific ++ ["Configuration rollback does not roll back financial effects or external operations."]
    )
  end
end
