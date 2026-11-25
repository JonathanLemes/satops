defmodule SatOps.Blockchain.NodeSupervisor do
  use DynamicSupervisor
  require Logger
  alias SatOps.Blockchain.NodeMonitor

  def start_link(_), do: DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)

  @impl true
  def init(_), do: DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 20, max_seconds: 60)

  def start_all do
    if enabled?() do
      SatOps.Integrations.list_all_enabled("bitcoin_core") |> Enum.each(&start_node/1)
    end

    :ok
  end

  def start_node(integration) do
    if enabled?() and Process.whereis(__MODULE__) do
      DynamicSupervisor.start_child(__MODULE__, {NodeMonitor, integration})
    else
      :ignore
    end
  end

  def stop_node(integration_id) do
    case Registry.lookup(SatOps.Registry, {:node, integration_id}) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> :ok
    end
  end

  def restart_node(integration) do
    stop_node(integration.id)
    if integration.enabled, do: start_node(integration), else: :ok
  end

  def running do
    Registry.select(SatOps.Registry, [{{{:node, :"$1"}, :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
  end

  defp enabled?, do: Application.get_env(:sat_ops, :start_integrations, true) and SatOps.Application.worker?()
end
