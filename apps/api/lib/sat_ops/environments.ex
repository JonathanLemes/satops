defmodule SatOps.Environments do
  import Ecto.Query
  alias SatOps.{Audit, Repo}
  alias SatOps.Environments.Environment

  def list(:all), do: Repo.all(from e in Environment, where: e.status == "active", order_by: e.inserted_at)

  def list(ids) when is_list(ids),
    do: Repo.all(from e in Environment, where: e.id in ^ids and e.status == "active", order_by: e.inserted_at)

  def get(id), do: Repo.get(Environment, id)
  def get!(id), do: Repo.get!(Environment, id)
  def get_by_slug(slug), do: Repo.get_by(Environment, slug: slug)

  def resolve(ref) when is_binary(ref) do
    case Ecto.UUID.cast(ref) do
      {:ok, id} -> get(id)
      :error -> get_by_slug(ref)
    end
  end

  def create(attrs, actor) do
    Repo.transaction(fn ->
      case %Environment{} |> Environment.changeset(attrs) |> Repo.insert() do
        {:ok, env} ->
          Audit.record!(actor, "environment.created", resource: env, environment_id: env.id, changes: attrs)
          env

        {:error, cs} ->
          Repo.rollback(cs)
      end
    end)
  end

  def update(%Environment{} = env, attrs, actor) do
    Repo.transaction(fn ->
      case env |> Environment.changeset(attrs) |> Repo.update() do
        {:ok, updated} ->
          Audit.record!(actor, "environment.updated", resource: updated, changes: attrs)
          updated

        {:error, cs} ->
          Repo.rollback(cs)
      end
    end)
  end

  def upsert_by_slug(attrs, actor) do
    slug = attrs[:slug] || attrs["slug"]

    case get_by_slug(slug) do
      nil -> create(attrs, actor)
      env -> __MODULE__.update(env, attrs, actor)
    end
  end

  def ensure_default do
    case get_by_slug("default-sandbox") do
      nil ->
        {:ok, env} =
          create(
            %{
              slug: "default-sandbox",
              name: "Default sandbox",
              settings: %{
                "modules" => %{"satwatch" => true, "clearledger" => true, "satlab" => true},
                "safety" => %{"allowMainnet" => false, "allowPublicPeers" => false, "requireIsolatedNamespace" => true}
              }
            },
            nil
          )

        env

      env ->
        env
    end
  end

  def assert_regtest_chain("regtest"), do: :ok
  def assert_regtest_chain(other), do: {:error, {:unsafe_network, other}}
end
