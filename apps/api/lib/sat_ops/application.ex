defmodule SatOps.Application do
  use Application

  @impl true
  def start(_type, _args) do
    SatOps.Observability.setup()

    children =
      [
        SatOps.Observability.Metrics,
        SatOps.Repo,
        {Phoenix.PubSub, name: SatOps.PubSub},
        {Registry, keys: :unique, name: SatOps.Registry},
        {Task.Supervisor, name: SatOps.TaskSupervisor},
        SatOps.Identity.RateLimiter,
        {Oban, Application.fetch_env!(:sat_ops, Oban)},
        SatOps.Blockchain.NodeSupervisor,
        {Task, &boot/0}
      ] ++ endpoint()

    Supervisor.start_link(children, strategy: :one_for_one, name: SatOps.Supervisor)
  end

  defp endpoint, do: if(api?(), do: [SatOpsWeb.Endpoint], else: [])

  defp boot do
    if Application.get_env(:sat_ops, :start_integrations, true) do
      SatOps.Release.bootstrap()
      SatOps.Blockchain.NodeSupervisor.start_all()
    end
  end

  def role, do: Application.get_env(:sat_ops, :role, :all)
  def api?, do: role() in [:all, :api]
  def worker?, do: role() in [:all, :worker]

  @impl true
  def config_change(changed, _new, removed) do
    SatOpsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
