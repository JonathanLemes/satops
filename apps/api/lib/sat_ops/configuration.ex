defmodule SatOps.Configuration do
  import Ecto.Query
  require Logger
  alias SatOps.{Audit, Events, Repo}
  alias SatOps.Configuration.{Appliers, Resource, Revision, Schemas, Yaml}

  @kinds ~w(Environment BitcoinNetwork BitcoinIntegration FinancialIntegration ReconciliationPolicy Experiment Dashboard AlertPolicy)
  @api_version "satops.io/v1alpha1"

  def kinds, do: @kinds
  def api_version, do: @api_version

  def parse(yaml) when is_binary(yaml) do
    with {:ok, doc} <- Yaml.parse(yaml) do
      validate(doc)
    end
  end

  def validate(doc) when is_map(doc) do
    kind = doc["kind"]

    cond do
      doc["apiVersion"] != @api_version ->
        {:error, [%{path: "/apiVersion", message: "must be #{@api_version}"}]}

      kind not in @kinds ->
        {:error, [%{path: "/kind", message: "must be one of #{Enum.join(@kinds, ", ")}"}]}

      true ->
        with :ok <- Schemas.validate(kind, doc),
             :ok <- semantic_checks(doc) do
          {:ok, doc}
        end
    end
  end

  def validate(_), do: {:error, [%{path: "/", message: "document must be a mapping"}]}

  defp semantic_checks(%{"kind" => kind, "spec" => spec})
       when kind in [
              "BitcoinIntegration",
              "FinancialIntegration",
              "AlertPolicy",
              "ReconciliationPolicy",
              "BitcoinNetwork"
            ] do
    if SatOps.Environments.get_by_slug(spec["environmentRef"]) || pending_environment?(spec["environmentRef"]) do
      :ok
    else
      {:error, [%{path: "/spec/environmentRef", message: "environment #{spec["environmentRef"]} does not exist"}]}
    end
  end

  defp semantic_checks(%{"kind" => "Experiment", "spec" => spec}) do
    case SatOps.Experiments.ScenarioSpec.validate(spec) do
      :ok -> :ok
      {:error, errors} -> {:error, Enum.map(errors, &%{path: "/spec", message: &1})}
    end
  end

  defp semantic_checks(_), do: :ok

  defp pending_environment?(slug),
    do: Repo.exists?(from r in Resource, where: r.kind == "Environment" and r.name == ^slug and is_nil(r.deleted_at))

  def get(kind, name),
    do: Repo.one(from r in Resource, where: r.kind == ^kind and r.name == ^name and is_nil(r.deleted_at))

  def list(opts \\ []) do
    Resource
    |> where([r], is_nil(r.deleted_at))
    |> then(fn q -> if k = opts[:kind], do: where(q, [r], r.kind == ^k), else: q end)
    |> order_by([r], [r.kind, r.name])
    |> Repo.all()
  end

  def revisions(resource_id),
    do: Repo.all(from v in Revision, where: v.resource_id == ^resource_id, order_by: [desc: v.revision])

  def revision(resource_id, n), do: Repo.get_by(Revision, resource_id: resource_id, revision: n)

  def desired(%Resource{} = r), do: revision(r.id, r.desired_revision)

  def applied_spec(kind, name) do
    with %Resource{applied_revision: rev} = r when is_integer(rev) <- get(kind, name),
         %Revision{spec: spec} <- revision(r.id, rev) do
      %{"spec" => spec["spec"], "revision" => rev}
    else
      _ -> nil
    end
  end

  def export(%Resource{} = r) do
    case desired(r) do
      %Revision{spec: spec} -> Yaml.encode(spec)
      nil -> nil
    end
  end

  def plan(doc) do
    with {:ok, doc} <- validate(doc) do
      current = get(doc["kind"], doc["metadata"]["name"])
      current_spec = current && desired(current) && desired(current).spec
      changes = diff(current_spec || %{}, doc)

      {:ok,
       %{
         action:
           cond do
             is_nil(current) -> "create"
             changes == [] -> "noop"
             true -> "update"
           end,
         kind: doc["kind"],
         name: doc["metadata"]["name"],
         current_revision: current && current.desired_revision,
         changes: changes,
         impact: Appliers.impact(doc, current_spec, changes),
         canonical_yaml: Yaml.encode(doc),
         current_yaml: current_spec && Yaml.encode(current_spec)
       }}
    end
  end

  def diff(old, new, path \\ "")

  def diff(old, new, path) when is_map(old) and is_map(new) do
    keys = (Map.keys(old) ++ Map.keys(new)) |> Enum.uniq() |> Enum.sort()

    Enum.flat_map(keys, fn k ->
      p = "#{path}/#{k}"

      case {Map.fetch(old, k), Map.fetch(new, k)} do
        {:error, {:ok, v}} -> [%{op: "add", path: p, old: nil, new: v}]
        {{:ok, v}, :error} -> [%{op: "remove", path: p, old: v, new: nil}]
        {{:ok, a}, {:ok, b}} -> diff(a, b, p)
      end
    end)
  end

  def diff(same, same, _path), do: []
  def diff(old, new, path), do: [%{op: "replace", path: if(path == "", do: "/", else: path), old: old, new: new}]

  def apply_document(doc, opts) do
    actor = opts[:actor]
    expected = opts[:expected_revision]

    with {:ok, doc} <- validate(doc) do
      kind = doc["kind"]
      name = doc["metadata"]["name"]
      spec_hash = hash(doc)

      result =
        Repo.transaction(fn ->
          Repo.query!("SELECT pg_advisory_xact_lock(hashtext($1))", ["config:#{kind}:#{name}"])
          current = get(kind, name)

          cond do
            current && expected && expected != current.desired_revision ->
              Repo.rollback({:conflict, current.desired_revision})

            is_nil(current) && expected && expected != 0 ->
              Repo.rollback({:conflict, 0})

            current && (desired(current) || %{}) |> Map.get(:spec_hash) == spec_hash ->
              {:unchanged, current}

            true ->
              resource = upsert_resource(current, doc)
              rev = resource.desired_revision

              Repo.insert!(%Revision{
                resource_id: resource.id,
                revision: rev,
                api_version: @api_version,
                spec: doc,
                spec_hash: spec_hash,
                yaml: Yaml.encode(doc),
                author_id: actor && actor.id,
                author_email: actor && actor.email,
                message: opts[:message],
                inserted_at: DateTime.utc_now()
              })

              Audit.record!(actor, "config.revision_created",
                resource_type: "config:#{kind}",
                resource_id: name,
                changes: %{revision: rev, message: opts[:message]}
              )

              {:changed, resource}
          end
        end)

      case result do
        {:ok, {:unchanged, resource}} -> {:ok, %{resource: reconcile(resource), changed: false}}
        {:ok, {:changed, resource}} -> {:ok, %{resource: reconcile(resource), changed: true}}
        {:error, {:conflict, rev}} -> {:error, {:conflict, rev}}
        {:error, other} -> {:error, other}
      end
    end
  end

  def apply_yaml(yaml, opts) do
    with {:ok, doc} <- Yaml.parse(yaml) do
      apply_document(doc, opts)
    end
  end

  def reapply_revision(%Resource{} = resource, revision_number, actor) do
    case revision(resource.id, revision_number) do
      nil ->
        {:error, :not_found}

      rev ->
        apply_document(rev.spec,
          actor: actor,
          expected_revision: resource.desired_revision,
          message: "re-apply of revision #{revision_number}"
        )
    end
  end

  defp upsert_resource(nil, doc) do
    now = DateTime.utc_now()

    Repo.insert!(%Resource{
      kind: doc["kind"],
      name: doc["metadata"]["name"],
      environment_ref: get_in(doc, ["spec", "environmentRef"]),
      desired_revision: 1,
      status: "pending",
      inserted_at: now,
      updated_at: now
    })
  end

  defp upsert_resource(%Resource{} = r, doc) do
    r
    |> Ecto.Changeset.change(
      desired_revision: r.desired_revision + 1,
      status: "pending",
      environment_ref: get_in(doc, ["spec", "environmentRef"]),
      status_message: nil
    )
    |> Ecto.Changeset.optimistic_lock(:lock_version)
    |> Repo.update!()
  end

  def reconcile(%Resource{} = resource) do
    resource = Repo.get!(Resource, resource.id)
    rev = revision(resource.id, resource.desired_revision)

    if resource.applied_revision == resource.desired_revision and resource.status == "applied" do
      observe(resource, rev)
    else
      case Appliers.apply(rev.spec, resource) do
        {:ok, observed} ->
          updated =
            resource
            |> Ecto.Changeset.change(
              applied_revision: rev.revision,
              status: "applied",
              observed: observed,
              status_message: nil,
              updated_at: DateTime.utc_now()
            )
            |> Repo.update!()

          env_id = observed["environmentId"]

          if env_id do
            Repo.transaction(fn ->
              Events.append!(%{
                event_type: "config.applied",
                environment_id: env_id,
                aggregate_type: "config",
                aggregate_id: "#{resource.kind}/#{resource.name}",
                aggregate_version: rev.revision,
                payload: %{"kind" => resource.kind, "name" => resource.name, "revision" => rev.revision}
              })
            end)
          end

          updated

        {:error, reason} ->
          Logger.warning("config apply failed for #{resource.kind}/#{resource.name}: #{inspect(reason)}")

          resource
          |> Ecto.Changeset.change(
            status: "failed",
            status_message: format_reason(reason),
            updated_at: DateTime.utc_now()
          )
          |> Repo.update!()
      end
    end
  end

  defp observe(resource, rev) do
    observed = Appliers.observe(rev.spec)

    if observed != resource.observed do
      resource |> Ecto.Changeset.change(observed: observed) |> Repo.update!()
    else
      resource
    end
  end

  def reconcile_all do
    for r <- list(), do: reconcile(r)
    :ok
  end

  defp format_reason(%Ecto.Changeset{} = cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(inspect(v))) end)
    end)
    |> inspect()
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)

  defp hash(doc), do: :crypto.hash(:sha256, Jason.encode!(canonical(doc))) |> Base.encode16(case: :lower)

  defp canonical(map) when is_map(map),
    do: map |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(fn {k, v} -> [k, canonical(v)] end)

  defp canonical(list) when is_list(list), do: Enum.map(list, &canonical/1)
  defp canonical(v), do: v

  def delete(%Resource{} = r, actor) do
    Repo.transaction(fn ->
      r |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(), status: "deleted") |> Repo.update!()
      Audit.record!(actor, "config.deleted", resource_type: "config:#{r.kind}", resource_id: r.name)
    end)
  end
end
