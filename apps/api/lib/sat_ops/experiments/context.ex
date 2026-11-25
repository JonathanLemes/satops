defmodule SatOps.Experiments.Context do
  alias SatOps.{Integrations, Repo}
  alias SatOps.Infrastructure.Bitcoin.RPC
  alias SatOps.Integrations.Adapters.BitcoinCore
  import Ecto.Query

  defstruct [:run, :env, :refs, :seed, :correlation_id]

  def build(run, env) do
    refs =
      Repo.all(
        from s in SatOps.Experiments.Step,
          where: s.run_id == ^run.id and s.status == "succeeded",
          order_by: s.position,
          select: s.result
      )
      |> Enum.reduce(%{}, fn result, acc -> Map.merge(acc, (result || %{})["refs"] || %{}) end)

    %__MODULE__{run: run, env: env, refs: refs, seed: run.seed, correlation_id: run.correlation_id}
  end

  def node(ctx, name \\ nil) do
    nodes = Integrations.list(ctx.env.id, kind: "bitcoin_core")

    node =
      case name do
        nil ->
          nodes |> Enum.filter(& &1.enabled) |> Enum.sort_by(&{&1.config["priority"] || 100, &1.name}) |> List.first()

        n ->
          Enum.find(nodes, &(&1.name == n))
      end

    case node do
      nil ->
        {:error, "bitcoin node #{name || "(default)"} not found in environment"}

      integration ->
        with {:ok, creds} <- Integrations.credentials(integration),
             do: {:ok, integration, BitcoinCore.rpc(integration, creds)}
    end
  end

  def rpc(ctx, name \\ nil, wallet \\ nil) do
    with {:ok, _i, rpc} <- node(ctx, name) do
      {:ok, if(wallet, do: RPC.with_wallet(rpc, wallet), else: %{rpc | wallet: nil})}
    end
  end

  def fintech(ctx, name \\ nil) do
    candidates = Integrations.list(ctx.env.id, kind: "demo_fintech", enabled: true)
    integration = if name, do: Enum.find(candidates, &(&1.name == name)), else: List.first(candidates)

    case integration do
      nil -> {:error, "demo fintech integration not found"}
      i -> with {:ok, token} <- Integrations.credentials(i), do: {:ok, i, token}
    end
  end

  def ref(ctx, key) do
    case Map.fetch(ctx.refs, key) do
      {:ok, v} -> {:ok, v}
      :error -> {:error, "reference #{key} was not produced by a previous step"}
    end
  end

  def resolve(ctx, %{"ref" => key}), do: ref(ctx, key)

  def resolve(ctx, key) when is_binary(key) do
    case Map.fetch(ctx.refs, key) do
      {:ok, v} -> {:ok, v}
      :error -> {:ok, key}
    end
  end

  def resolve(_ctx, value), do: {:ok, value}
end
