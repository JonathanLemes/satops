defmodule SatOps.Infrastructure.Kubernetes do
  def available?, do: Application.get_env(:sat_ops, :runtime) == :kubernetes

  def conn do
    if available?() do
      K8s.Conn.from_service_account()
    else
      {:error, :kubernetes_runtime_not_configured}
    end
  end

  def authorized_namespace?(namespace) do
    namespace in Application.get_env(:sat_ops, :kubernetes_sandbox_namespaces, []) and
      String.starts_with?(namespace, "sandbox-")
  end

  def restart_workload(namespace, kind, name) do
    patch = %{
      "spec" => %{
        "template" => %{
          "metadata" => %{"annotations" => %{"satops.io/restartedAt" => DateTime.to_iso8601(DateTime.utc_now())}}
        }
      }
    }

    with :ok <- guard(namespace), {:ok, conn} <- conn() do
      op = K8s.Client.patch("apps/v1", kind, [namespace: namespace, name: name], patch, :merge)
      K8s.Client.run(conn, op)
    end
  end

  def delete_pod(namespace, name) do
    with :ok <- guard(namespace), {:ok, conn} <- conn() do
      K8s.Client.run(conn, K8s.Client.delete("v1", "Pod", namespace: namespace, name: name))
    end
  end

  def scale_workload(namespace, kind, name, replicas) when replicas in 0..5 do
    with :ok <- guard(namespace), {:ok, conn} <- conn() do
      op =
        K8s.Client.patch(
          "apps/v1",
          kind,
          [namespace: namespace, name: name],
          %{"spec" => %{"replicas" => replicas}},
          :merge
        )

      K8s.Client.run(conn, op)
    end
  end

  def isolate_workload(namespace, app_label, owner_ref) do
    policy = %{
      "apiVersion" => "networking.k8s.io/v1",
      "kind" => "NetworkPolicy",
      "metadata" => %{
        "name" => "satops-isolate-#{app_label}",
        "namespace" => namespace,
        "labels" => %{"satops.io/owner" => owner_ref, "app.kubernetes.io/managed-by" => "satops"}
      },
      "spec" => %{"podSelector" => %{"matchLabels" => %{"app" => app_label}}, "policyTypes" => ["Ingress", "Egress"]}
    }

    with :ok <- guard(namespace), {:ok, conn} <- conn() do
      K8s.Client.run(conn, K8s.Client.apply(policy, field_manager: "satops", force: true))
    end
  end

  def remove_isolation(namespace, app_label) do
    with :ok <- guard(namespace), {:ok, conn} <- conn() do
      K8s.Client.run(
        conn,
        K8s.Client.delete("networking.k8s.io/v1", "NetworkPolicy",
          namespace: namespace,
          name: "satops-isolate-#{app_label}"
        )
      )
    end
  end

  defp guard(namespace) do
    if authorized_namespace?(namespace), do: :ok, else: {:error, {:namespace_not_authorized, namespace}}
  end
end
