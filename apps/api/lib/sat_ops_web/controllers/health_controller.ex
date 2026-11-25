defmodule SatOpsWeb.HealthController do
  use SatOpsWeb, :controller

  def live(conn, _params), do: json(conn, %{status: "ok"})

  def ready(conn, _params) do
    db =
      case SatOps.Repo.query("SELECT 1") do
        {:ok, _} -> "ok"
        _ -> "unavailable"
      end

    status = if db == "ok", do: 200, else: 503

    conn
    |> put_status(status)
    |> json(%{status: if(status == 200, do: "ready", else: "not_ready"), database: db, role: SatOps.Application.role()})
  end

  def metrics(conn, _params) do
    conn |> put_resp_content_type("text/plain; version=0.0.4") |> send_resp(200, SatOps.Observability.Metrics.scrape())
  end
end
