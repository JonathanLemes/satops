defmodule SatOps.Dashboards do
  import Ecto.Query
  alias SatOps.{Audit, Configuration, Repo}

  defmodule Dashboard do
    use SatOps.Schema

    schema "dashboards" do
      field :environment_id, :binary_id
      field :owner_id, :binary_id
      field :name, :string
      field :title, :string
      field :workspace, :string
      field :spec, :map
      field :is_default, :boolean, default: false
      field :lock_version, :integer, default: 1
      timestamps()
    end
  end

  @widgets [
    %{
      type: "transactions.volume",
      context: "blockchain",
      min: {4, 2},
      permission: "blockchain.read",
      refresh: "poll",
      workspaces: ["customer", "engineering"]
    },
    %{
      type: "balance.confirmed",
      context: "wallet_monitoring",
      min: {2, 1},
      permission: "wallet.read",
      refresh: "realtime",
      workspaces: ["customer"]
    },
    %{
      type: "balance.pending",
      context: "wallet_monitoring",
      min: {2, 1},
      permission: "wallet.read",
      refresh: "realtime",
      workspaces: ["customer"]
    },
    %{
      type: "blockchain.nodes",
      context: "blockchain",
      min: {3, 2},
      permission: "blockchain.read",
      refresh: "realtime",
      workspaces: ["customer", "engineering"]
    },
    %{
      type: "blockchain.height",
      context: "blockchain",
      min: {2, 1},
      permission: "blockchain.read",
      refresh: "realtime",
      workspaces: ["customer", "engineering"]
    },
    %{
      type: "blockchain.mempool",
      context: "blockchain",
      min: {2, 1},
      permission: "blockchain.read",
      refresh: "realtime",
      workspaces: ["engineering"]
    },
    %{
      type: "transactions.recent",
      context: "blockchain",
      min: {4, 3},
      permission: "blockchain.read",
      refresh: "realtime",
      workspaces: ["customer", "engineering"]
    },
    %{
      type: "reconciliation.summary",
      context: "reconciliation",
      min: {3, 2},
      permission: "reconciliation.read",
      refresh: "realtime",
      workspaces: ["customer", "engineering"]
    },
    %{
      type: "reconciliation.open_discrepancies",
      context: "reconciliation",
      min: {2, 1},
      permission: "reconciliation.read",
      refresh: "realtime",
      workspaces: ["customer", "engineering"]
    },
    %{
      type: "reconciliation.history",
      context: "reconciliation",
      min: {4, 2},
      permission: "reconciliation.read",
      refresh: "poll",
      workspaces: ["customer", "engineering"]
    },
    %{
      type: "experiments.results",
      context: "experiments",
      min: {4, 2},
      permission: "experiment.read",
      refresh: "realtime",
      workspaces: ["engineering"]
    },
    %{
      type: "experiments.active",
      context: "experiments",
      min: {3, 2},
      permission: "experiment.read",
      refresh: "realtime",
      workspaces: ["engineering"]
    },
    %{
      type: "jobs.status",
      context: "platform",
      min: {3, 2},
      permission: "jobs.read",
      refresh: "poll",
      workspaces: ["engineering"]
    },
    %{
      type: "ingestion.latency",
      context: "blockchain",
      min: {3, 2},
      permission: "blockchain.read",
      refresh: "poll",
      workspaces: ["engineering"]
    },
    %{
      type: "blockchain.reorganizations",
      context: "blockchain",
      min: {3, 2},
      permission: "blockchain.read",
      refresh: "realtime",
      workspaces: ["engineering"]
    }
  ]

  def widget_types, do: @widgets

  def defaults do
    %{
      "customer-overview" => %{
        "title" => "Financial overview",
        "workspace" => "customer",
        "layout" => %{"columns" => 12},
        "widgets" => [
          w("confirmed", "balance.confirmed", 0, 0, 3, 1),
          w("pending", "balance.pending", 3, 0, 3, 1),
          w("open-discrepancies", "reconciliation.open_discrepancies", 6, 0, 3, 1),
          w("height", "blockchain.height", 9, 0, 3, 1),
          w("volume", "transactions.volume", 0, 1, 8, 3),
          w("reconciliation", "reconciliation.summary", 8, 1, 4, 3),
          w("recent", "transactions.recent", 0, 4, 8, 4),
          w("network", "blockchain.nodes", 8, 4, 4, 4)
        ]
      },
      "engineering-overview" => %{
        "title" => "Engineering overview",
        "workspace" => "engineering",
        "layout" => %{"columns" => 12},
        "widgets" => [
          w("node-health", "blockchain.nodes", 0, 0, 4, 3),
          w("reconciliation-rate", "reconciliation.summary", 4, 0, 4, 3),
          w("active-experiments", "experiments.active", 8, 0, 4, 3),
          w("height", "blockchain.height", 0, 3, 3, 1),
          w("mempool", "blockchain.mempool", 3, 3, 3, 1),
          w("discrepancies", "reconciliation.open_discrepancies", 6, 3, 3, 1),
          w("latency", "ingestion.latency", 9, 3, 3, 2),
          w("jobs", "jobs.status", 0, 4, 5, 3),
          w("reorgs", "blockchain.reorganizations", 5, 4, 4, 3),
          w("experiment-results", "experiments.results", 0, 7, 9, 3)
        ]
      }
    }
  end

  defp w(id, type, x, y, width, height),
    do: %{"id" => id, "type" => type, "position" => %{"x" => x, "y" => y, "width" => width, "height" => height}}

  def ensure_defaults do
    for {name, spec} <- defaults(), is_nil(get_shared(name)) do
      upsert_shared(name, spec, nil, true)
    end

    :ok
  end

  def get_shared(name), do: Repo.one(from d in Dashboard, where: is_nil(d.owner_id) and d.name == ^name)

  def list_for(user, workspace) do
    Repo.all(
      from d in Dashboard,
        where: d.workspace == ^workspace and (is_nil(d.owner_id) or d.owner_id == ^user.id),
        order_by: [desc: d.is_default, asc: d.title]
    )
  end

  def get(id), do: Repo.get(Dashboard, id)

  def validate_spec(name, spec) do
    Configuration.validate(%{
      "apiVersion" => Configuration.api_version(),
      "kind" => "Dashboard",
      "metadata" => %{"name" => name},
      "spec" => spec
    })
  end

  def upsert_shared(name, spec, actor, is_default \\ false) do
    with {:ok, _} <- validate_spec(name, spec) do
      Repo.transaction(fn ->
        dashboard = get_shared(name) || %Dashboard{name: name, is_default: is_default}

        result =
          dashboard
          |> Ecto.Changeset.change(title: spec["title"] || name, workspace: spec["workspace"], spec: spec)
          |> Repo.insert_or_update()

        case result do
          {:ok, d} ->
            if actor, do: Audit.record!(actor, "dashboard.saved", resource: d)
            d

          {:error, cs} ->
            Repo.rollback(cs)
        end
      end)
    end
  end

  def save_personal(user, attrs, actor) do
    name = attrs["name"]
    spec = attrs["spec"]

    with {:ok, _} <- validate_spec(name, spec) do
      existing = Repo.one(from d in Dashboard, where: d.owner_id == ^user.id and d.name == ^name)

      changeset =
        (existing || %Dashboard{owner_id: user.id, name: name})
        |> Ecto.Changeset.change(title: spec["title"] || name, workspace: spec["workspace"], spec: spec)

      changeset =
        if existing && attrs["lockVersion"],
          do:
            changeset
            |> Ecto.Changeset.force_change(:lock_version, existing.lock_version)
            |> Ecto.Changeset.optimistic_lock(:lock_version),
          else: changeset

      if existing && attrs["lockVersion"] && attrs["lockVersion"] != existing.lock_version do
        {:error, :stale}
      else
        with {:ok, d} <- Repo.insert_or_update(changeset) do
          Audit.record!(actor, "dashboard.saved", resource: d)
          {:ok, d}
        end
      end
    end
  rescue
    Ecto.StaleEntryError -> {:error, :stale}
  end

  def delete(%Dashboard{owner_id: owner} = d, user) when owner == user.id do
    Repo.delete(d)
  end

  def delete(_, _), do: {:error, :forbidden}

  def restore_default(user, workspace) do
    name = if workspace == "customer", do: "customer-overview", else: "engineering-overview"
    Repo.delete_all(from d in Dashboard, where: d.owner_id == ^user.id and d.name == ^name)
    {:ok, get_shared(name)}
  end
end
