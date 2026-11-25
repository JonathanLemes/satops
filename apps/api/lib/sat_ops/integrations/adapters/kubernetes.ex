defmodule SatOps.Integrations.Adapters.Kubernetes do
  @behaviour SatOps.Integrations.Adapter

  @impl true
  def capabilities,
    do: [
      "kubernetes.restart_workload",
      "kubernetes.delete_pod",
      "kubernetes.scale_workload",
      "kubernetes.isolate_workload"
    ]

  @impl true
  def validate_configuration(config) do
    config = Map.new(config, fn {k, v} -> {to_string(k), v} end)
    namespaces = config["namespaces"] || []

    cond do
      not is_list(namespaces) or namespaces == [] ->
        {:error, ["namespaces: at least one sandbox namespace is required"]}

      Enum.any?(namespaces, &(&1 in ["kube-system", "kube-public", "default", "satops-system", "satops-data"])) ->
        {:error, ["namespaces: system and platform namespaces cannot be experiment targets"]}

      true ->
        {:ok, %{"namespaces" => namespaces, "labelSelector" => config["labelSelector"] || "satops.io/sandbox=true"}}
    end
  end

  @impl true
  def health_check(_integration, _) do
    case SatOps.Infrastructure.Kubernetes.conn() do
      {:ok, _conn} -> {:ok, %{"status" => "in-cluster credentials available"}}
      {:error, reason} -> {:error, reason}
    end
  end
end
