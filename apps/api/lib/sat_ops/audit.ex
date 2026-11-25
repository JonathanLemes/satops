defmodule SatOps.Audit do
  import Ecto.Query
  alias SatOps.Repo

  defmodule Entry do
    use Ecto.Schema

    schema "audit_entries" do
      field :actor_id, :binary_id
      field :actor_email, :string
      field :action, :string
      field :environment_id, :binary_id
      field :resource_type, :string
      field :resource_id, :string
      field :changes, :map, default: %{}
      field :ip, :string
      field :correlation_id, :binary_id
      field :inserted_at, :utc_datetime_usec
    end
  end

  def record!(actor, action, opts \\ []) do
    {resource_type, resource_id} = resource(opts)

    Repo.insert!(%Entry{
      actor_id: actor && Map.get(actor, :id),
      actor_email: actor && Map.get(actor, :email),
      action: action,
      environment_id: opts[:environment_id] || environment_of(opts[:resource]),
      resource_type: resource_type,
      resource_id: resource_id,
      changes: opts |> Keyword.get(:changes, %{}) |> SatOps.Redactor.redact(),
      ip: opts[:ip],
      correlation_id: opts[:correlation_id],
      inserted_at: DateTime.utc_now()
    })
  end

  defp resource(opts) do
    case opts[:resource] do
      %{__struct__: mod, id: id} -> {opts[:resource_type] || short_name(mod), to_string(id)}
      _ -> {opts[:resource_type], opts[:resource_id] && to_string(opts[:resource_id])}
    end
  end

  defp environment_of(%{environment_id: env}), do: env
  defp environment_of(_), do: nil

  defp short_name(mod), do: mod |> Module.split() |> List.last() |> Macro.underscore()

  def list(filters \\ %{}, limit \\ 100) do
    Entry
    |> filter(filters)
    |> order_by(desc: :id)
    |> limit(^min(limit, 500))
    |> Repo.all()
  end

  defp filter(query, filters) do
    Enum.reduce(filters, query, fn
      {:environment_id, env}, q when is_binary(env) ->
        where(q, [e], e.environment_id == ^env or is_nil(e.environment_id))

      {:action, a}, q when is_binary(a) and a != "" ->
        where(q, [e], ilike(e.action, ^"#{a}%"))

      {:resource_id, r}, q when is_binary(r) ->
        where(q, [e], e.resource_id == ^r)

      {:correlation_id, c}, q when is_binary(c) ->
        where(q, [e], e.correlation_id == ^c)

      {:before_id, id}, q when is_integer(id) ->
        where(q, [e], e.id < ^id)

      _, q ->
        q
    end)
  end
end
