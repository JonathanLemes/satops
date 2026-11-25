defmodule SatOpsWeb.ReportController do
  use SatOpsWeb, :controller
  alias SatOps.{Configuration, Experiments, Reconciliation}

  def experiment(conn, %{"id" => id}) do
    with %{} = run <- Experiments.get_run(id),
         :ok <- authorize(conn, :"experiment.read", run.environment_id) do
      download(
        conn,
        "experiment-#{run.scenario_name}-#{String.slice(run.id, 0, 8)}.json",
        run.report || SatOps.Experiments.Report.build(run)
      )
    else
      nil -> error(conn, 404, "not_found")
      {:error, halted} -> halted
    end
  end

  def reconciliation(conn, %{"id" => id}) do
    with %{} = run <- Reconciliation.get_run(id),
         :ok <- authorize(conn, :"reconciliation.export", run.environment_id) do
      download(conn, "reconciliation-#{String.slice(run.id, 0, 8)}.json", Reconciliation.export_run(id))
    else
      nil -> error(conn, 404, "not_found")
      {:error, halted} -> halted
    end
  end

  def config(conn, %{"kind" => kind, "name" => name}) do
    with :ok <- authorize(conn, :"config.read"),
         %{} = resource <- Configuration.get(kind, name),
         yaml when is_binary(yaml) <- Configuration.export(resource) do
      conn
      |> put_resp_content_type("application/yaml")
      |> put_resp_header("content-disposition", ~s(attachment; filename="#{kind}-#{name}.yaml"))
      |> send_resp(200, yaml)
    else
      {:error, halted} -> halted
      _ -> error(conn, 404, "not_found")
    end
  end

  defp download(conn, filename, data) do
    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, Jason.encode_to_iodata!(data, pretty: true))
  end
end
