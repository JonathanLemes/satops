defmodule SatOps.Alerts do
  import Ecto.Query
  alias SatOps.{Audit, Repo}

  defmodule Policy do
    use SatOps.Schema

    @event_types ~w(node.disconnected integration.unavailable transaction.confirmation_delayed chain.reorganized
      reconciliation.discrepancy_detected reconciliation.completed reconciliation.incomplete experiment.finished
      ledger.invariant_violated node.diverged ledger.deposit_reversed)

    schema "alert_policies" do
      field :environment_id, :binary_id
      field :name, :string
      field :event_types, {:array, :string}
      field :severity, :string, default: "warning"
      field :cooldown_seconds, :integer, default: 300
      field :destinations, {:array, :map}, default: []
      field :enabled, :boolean, default: true
      timestamps()
    end

    def event_types, do: @event_types

    def changeset(policy, attrs) do
      policy
      |> cast(attrs, [:environment_id, :name, :event_types, :severity, :cooldown_seconds, :destinations, :enabled])
      |> validate_required([:environment_id, :name, :event_types])
      |> validate_subset(:event_types, @event_types)
      |> validate_length(:event_types, min: 1)
      |> validate_inclusion(:severity, ["info", "warning", "critical"])
      |> validate_number(:cooldown_seconds, greater_than_or_equal_to: 0, less_than_or_equal_to: 86_400)
      |> validate_change(:destinations, fn :destinations, dests ->
        if Enum.all?(dests, &(&1["type"] in ["internal", "webhook"])),
          do: [],
          else: [destinations: "type must be internal or webhook"]
      end)
      |> unique_constraint([:environment_id, :name])
    end
  end

  defmodule Occurrence do
    use SatOps.Schema

    schema "alert_occurrences" do
      field :environment_id, :binary_id
      belongs_to :policy, SatOps.Alerts.Policy
      field :fingerprint, :string
      field :state, :string, default: "firing"
      field :severity, :string
      field :title, :string
      field :details, :map, default: %{}
      field :first_event_id, :binary_id
      field :last_event_id, :binary_id
      field :count, :integer, default: 1
      field :first_seen_at, :utc_datetime_usec
      field :last_seen_at, :utc_datetime_usec
      field :last_notified_at, :utc_datetime_usec
      field :acknowledged_by, :binary_id
      field :resolved_at, :utc_datetime_usec
      has_many :deliveries, SatOps.Alerts.Delivery
      timestamps()
    end
  end

  defmodule Delivery do
    use Ecto.Schema

    schema "alert_deliveries" do
      belongs_to :occurrence, SatOps.Alerts.Occurrence, type: :binary_id
      field :destination, :string
      field :kind, :string
      field :status, :string, default: "pending"
      field :attempts, :integer, default: 0
      field :last_error, :string
      field :response_status, :integer
      field :delivered_at, :utc_datetime_usec
      field :inserted_at, :utc_datetime_usec
      field :updated_at, :utc_datetime_usec
    end
  end

  def list_policies(environment_id),
    do: Repo.all(from p in Policy, where: p.environment_id == ^environment_id, order_by: p.name)

  def upsert_policy(environment_id, attrs, actor) do
    name = attrs["name"] || attrs[:name]

    Repo.transaction(fn ->
      existing = Repo.get_by(Policy, environment_id: environment_id, name: name) || %Policy{}

      case existing
           |> Policy.changeset(Map.put(stringify(attrs), "environment_id", environment_id))
           |> Repo.insert_or_update() do
        {:ok, p} ->
          Audit.record!(actor, "alert_policy.saved", resource: p, changes: %{name: p.name})
          p

        {:error, cs} ->
          Repo.rollback(cs)
      end
    end)
  end

  def delete_policy(policy, actor) do
    Repo.transaction(fn ->
      Repo.delete!(policy)
      Audit.record!(actor, "alert_policy.deleted", resource: policy)
    end)
  end

  defp stringify(m), do: Map.new(m, fn {k, v} -> {to_string(k), v} end)

  def get_policy(id), do: Repo.get(Policy, id)

  def list_occurrences(environment_id, opts \\ []) do
    Occurrence
    |> where([o], o.environment_id == ^environment_id)
    |> then(fn q -> if s = opts[:state], do: where(q, [o], o.state == ^s), else: q end)
    |> order_by([o], desc: o.last_seen_at)
    |> limit(^min(opts[:limit] || 50, 200))
    |> preload([:policy, :deliveries])
    |> Repo.all()
  end

  def get_occurrence(id), do: Repo.get(Occurrence, id) |> Repo.preload([:policy, :deliveries])

  def fingerprint(event) do
    scope =
      case event.event_type do
        "node.disconnected" -> event.aggregate_id
        "integration.unavailable" -> event.aggregate_id
        "reconciliation.discrepancy_detected" -> event.payload["fingerprint"] || event.aggregate_id
        "ledger.invariant_violated" -> "ledger"
        _ -> event.aggregate_id
      end

    "#{event.event_type}:#{scope}"
  end

  def resolves(event) do
    case event.event_type do
      "node.reconnected" -> [{"node.disconnected", event.aggregate_id}]
      "integration.recovered" -> [{"integration.unavailable", event.aggregate_id}]
      _ -> []
    end
  end

  def record_event(event) do
    now = DateTime.utc_now()

    for {type, scope} <- resolves(event) do
      from(o in Occurrence,
        where:
          o.environment_id == ^event.environment_id and o.fingerprint == ^"#{type}:#{scope}" and
            o.state in ["firing", "acknowledged"]
      )
      |> Repo.update_all(set: [state: "resolved", resolved_at: now, updated_at: now])
    end

    policies =
      Repo.all(
        from p in Policy,
          where: p.environment_id == ^event.environment_id and p.enabled and ^event.event_type in p.event_types
      )

    Enum.each(policies, &fire(&1, event, now))
    :ok
  end

  defp fire(policy, event, now) do
    fp = fingerprint(event)

    active =
      Repo.one(
        from o in Occurrence,
          where: o.policy_id == ^policy.id and o.fingerprint == ^fp and o.state in ["firing", "acknowledged"],
          lock: "FOR UPDATE"
      )

    case active do
      nil ->
        occ =
          Repo.insert!(%Occurrence{
            environment_id: event.environment_id,
            policy_id: policy.id,
            fingerprint: fp,
            severity: policy.severity,
            title: title(event),
            details: %{"event_type" => event.event_type, "payload" => SatOps.Redactor.redact(event.payload)},
            first_event_id: event.id,
            last_event_id: event.id,
            first_seen_at: now,
            last_seen_at: now,
            last_notified_at: now
          })

        notify(policy, occ, now)

      occ ->
        cooled = is_nil(occ.last_notified_at) or DateTime.diff(now, occ.last_notified_at) >= policy.cooldown_seconds
        changes = [count: occ.count + 1, last_seen_at: now, last_event_id: event.id, updated_at: now]
        changes = if cooled and occ.state == "firing", do: Keyword.put(changes, :last_notified_at, now), else: changes
        updated = occ |> Ecto.Changeset.change(changes) |> Repo.update!()
        if cooled and occ.state == "firing", do: notify(policy, updated, now)
    end
  end

  defp notify(policy, occ, now) do
    SatOps.Realtime.broadcast(occ.environment_id, "alert.fired", %{
      "occurrenceId" => occ.id,
      "title" => occ.title,
      "severity" => occ.severity
    })

    for dest <- policy.destinations, dest["type"] == "webhook" do
      delivery =
        Repo.insert!(%Delivery{
          occurrence_id: occ.id,
          destination: dest["integration"],
          kind: "webhook",
          inserted_at: now,
          updated_at: now
        })

      %{delivery_id: delivery.id} |> SatOps.Alerts.DeliveryWorker.new() |> Oban.insert!()
    end
  end

  defp title(event) do
    p = event.payload

    case event.event_type do
      "node.disconnected" -> "Bitcoin node #{p["integration"]} unavailable"
      "integration.unavailable" -> "Integration #{p["integration"]} unavailable"
      "chain.reorganized" -> "Blockchain reorganization of depth #{p["depth"]}"
      "reconciliation.discrepancy_detected" -> "Discrepancy detected: #{p["kind"]}"
      "reconciliation.completed" -> "Reconciliation completed"
      "reconciliation.incomplete" -> "Reconciliation incomplete: #{p["reason"]}"
      "experiment.finished" -> "Experiment #{p["scenario"]} finished: #{p["status"]}"
      "ledger.invariant_violated" -> "Financial invariant violated"
      "ledger.deposit_reversed" -> "Deposit reversed for #{p["account_ref"]}"
      "node.diverged" -> "Bitcoin nodes report different chain tips"
      other -> other
    end
  end

  def acknowledge(occurrence, actor) do
    Repo.transaction(fn ->
      updated = occurrence |> Ecto.Changeset.change(state: "acknowledged", acknowledged_by: actor.id) |> Repo.update!()

      Audit.record!(actor, "alert.acknowledged",
        environment_id: occurrence.environment_id,
        resource_type: "alert_occurrence",
        resource_id: occurrence.id
      )

      updated
    end)
  end

  def resolve(occurrence, actor) do
    Repo.transaction(fn ->
      updated =
        occurrence |> Ecto.Changeset.change(state: "resolved", resolved_at: DateTime.utc_now()) |> Repo.update!()

      Audit.record!(actor, "alert.resolved",
        environment_id: occurrence.environment_id,
        resource_type: "alert_occurrence",
        resource_id: occurrence.id
      )

      updated
    end)
  end

  def retry_delivery(delivery_id, actor) do
    Repo.transaction(fn ->
      delivery = Repo.get!(Delivery, delivery_id)

      if delivery.status in ["failed_terminal", "failed"] do
        delivery |> Ecto.Changeset.change(status: "pending", attempts: 0) |> Repo.update!()
        %{delivery_id: delivery.id} |> SatOps.Alerts.DeliveryWorker.new() |> Oban.insert!()
        Audit.record!(actor, "alert.delivery_retried", resource_type: "alert_delivery", resource_id: delivery.id)
        :ok
      else
        Repo.rollback(:not_retryable)
      end
    end)
  end
end

defmodule SatOps.Alerts.EventConsumer do
  @behaviour SatOps.Events.Consumer

  @impl true
  def name, do: "alerts"

  @impl true
  def interested?(type),
    do: type in SatOps.Alerts.Policy.event_types() or type in ["node.reconnected", "integration.recovered"]

  @impl true
  def handle(event), do: SatOps.Alerts.record_event(event)
end

defmodule SatOps.Alerts.DeliveryWorker do
  use Oban.Worker, queue: :alerts, max_attempts: 8
  alias SatOps.{Integrations, Repo, Secrets}
  alias SatOps.Alerts.{Delivery, Occurrence}

  @impl true
  def backoff(%Oban.Job{attempt: attempt}),
    do: div(SatOps.Backoff.delay(attempt, base_ms: 5_000, max_ms: 600_000), 1000)

  @impl true
  def perform(%Oban.Job{args: %{"delivery_id" => id}, attempt: attempt, max_attempts: max}) do
    delivery = Repo.get(Delivery, id)

    with %Delivery{status: status} when status in ["pending", "failed"] <- delivery,
         occ = Repo.get!(Occurrence, delivery.occurrence_id),
         integration when not is_nil(integration) <- Integrations.get_by_name(occ.environment_id, delivery.destination) do
      body =
        Jason.encode!(%{
          id: occ.id,
          title: occ.title,
          severity: occ.severity,
          state: occ.state,
          count: occ.count,
          details: occ.details
        })

      ts = System.system_time(:second)
      secret = signing_secret(integration)
      sig = :crypto.mac(:hmac, :sha256, secret, "#{ts}.#{body}") |> Base.encode16(case: :lower)

      result =
        SatOps.Integrations.Http.request(:post, integration.config["url"],
          body: body,
          headers: [
            {"content-type", "application/json"},
            {"x-satops-signature", "t=#{ts},v1=#{sig}"},
            {"x-satops-delivery", "#{delivery.id}-#{occ.count}"}
          ],
          timeout: integration.config["timeoutMs"] || 5_000,
          max_attempts: 1
        )

      now = DateTime.utc_now()

      case result do
        {:ok, resp} ->
          update(delivery,
            status: "delivered",
            attempts: attempt,
            response_status: resp.status,
            delivered_at: now,
            last_error: nil
          )

          :ok

        {:error, reason} ->
          terminal = attempt >= max

          update(delivery,
            status: if(terminal, do: "failed_terminal", else: "failed"),
            attempts: attempt,
            last_error: Integrations.format_error(reason)
          )

          if terminal, do: {:cancel, :exhausted}, else: {:error, reason}
      end
    else
      nil -> {:cancel, :missing}
      %Delivery{} -> :ok
    end
  end

  defp update(delivery, changes) do
    delivery |> Ecto.Changeset.change(Keyword.put(changes, :updated_at, DateTime.utc_now())) |> Repo.update!()
  end

  defp signing_secret(integration) do
    case integration.secret_ref && Secrets.fetch(integration.environment_id, integration.secret_ref) do
      {:ok, s} -> s
      _ -> "unsigned"
    end
  end
end
