defmodule SatOpsWeb.GraphQL.Types.Operations do
  use Absinthe.Schema.Notation
  import SatOpsWeb.GraphQL.Helpers

  alias SatOps.{
    Alerts,
    Blockchain,
    Configuration,
    Dashboards,
    Environments,
    Experiments,
    Reconciliation,
    WalletMonitoring
  }

  alias SatOps.Configuration.{Schemas, Yaml}
  alias SatOpsWeb.GraphQL.Authorize

  object :scenario do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :version, non_null(:integer)
    field :title, non_null(:string)
    field :description, :string
    field :guarantee, :string
    field :required_capabilities, non_null(list_of(non_null(:string)))
    field :spec, :json
    field :inserted_at, :datetime

    field :versions, non_null(list_of(non_null(:integer))) do
      resolve fn s, _, _ -> {:ok, Experiments.scenario_versions(s.name) |> Enum.map(& &1.version)} end
    end
  end

  object :experiment_step do
    field :id, non_null(:id)
    field :position, non_null(:integer)
    field :step_key, non_null(:string)
    field :phase, non_null(:string)
    field :action, non_null(:string)
    field :params, :json
    field :status, non_null(:string)
    field :attempts, non_null(:integer)
    field :max_attempts, non_null(:integer)
    field :timeout_ms, non_null(:integer)
    field :checkpoint, :json
    field :result, :json
    field :evidence, :json
    field :failure_reason, :string
    field :started_at, :datetime
    field :finished_at, :datetime
  end

  object :assertion_result do
    field :id, non_null(:id)
    field :position, non_null(:integer)
    field :type, non_null(:string)
    field :params, :json
    field :outcome, non_null(:string)
    field :expected, :json
    field :actual, :json
    field :message, :string
    field :attempts, non_null(:integer)
    field :evaluated_at, non_null(:datetime)
  end

  object :experiment_run do
    field :id, non_null(:id)
    field :environment_id, non_null(:id)
    field :scenario_id, non_null(:id)
    field :scenario_name, non_null(:string)
    field :scenario_version, non_null(:integer)
    field :status, non_null(:string)
    field :seed, non_null(:string), resolve: fn r, _, _ -> {:ok, Integer.to_string(r.seed)} end
    field :status_reason, :string
    field :cleanup_status, non_null(:string)
    field :started_at, :datetime
    field :finished_at, :datetime
    field :inserted_at, non_null(:datetime)
    field :report, :json

    field :steps, non_null(list_of(non_null(:experiment_step))) do
      resolve fn r, _, _ -> {:ok, Experiments.get_run(r.id).steps} end
    end

    field :assertions, non_null(list_of(non_null(:assertion_result))) do
      resolve fn r, _, _ -> {:ok, Experiments.get_run(r.id).assertions} end
    end
  end

  object :action_descriptor do
    field :name, non_null(:string)
    field :idempotency, non_null(:string), resolve: fn a, _, _ -> {:ok, to_string(a.idempotency)} end
    field :capabilities, non_null(list_of(non_null(:string)))
  end

  object :config_resource do
    field :id, non_null(:id)
    field :kind, non_null(:string)
    field :name, non_null(:string)
    field :environment_ref, :string
    field :desired_revision, non_null(:integer)
    field :applied_revision, :integer
    field :status, non_null(:string)
    field :status_message, :string
    field :observed, :json
    field :updated_at, non_null(:datetime)

    field :yaml, :string, resolve: fn r, _, _ -> {:ok, Configuration.export(r)} end

    field :document, :json do
      resolve fn r, _, _ -> {:ok, (Configuration.desired(r) || %{spec: nil}).spec} end
    end

    field :revisions, non_null(list_of(non_null(:config_revision))) do
      resolve fn r, _, _ -> {:ok, Configuration.revisions(r.id)} end
    end
  end

  object :config_revision do
    field :revision, non_null(:integer)
    field :spec, :json
    field :yaml, non_null(:string)
    field :author_email, :string
    field :message, :string
    field :inserted_at, non_null(:datetime)
  end

  object :config_issue do
    field :path, :string
    field :message, non_null(:string)
    field :line, :integer
    field :column, :integer
  end

  object :config_validation do
    field :valid, non_null(:boolean)
    field :document, :json
    field :canonical_yaml, :string
    field :errors, non_null(list_of(non_null(:config_issue)))
  end

  object :config_change do
    field :op, non_null(:string)
    field :path, non_null(:string)
    field :old, :json
    field :new, :json
  end

  object :config_plan do
    field :action, non_null(:string)
    field :kind, non_null(:string)
    field :name, non_null(:string)
    field :current_revision, :integer
    field :changes, non_null(list_of(non_null(:config_change)))
    field :impact, non_null(list_of(non_null(:string)))
    field :canonical_yaml, non_null(:string)
    field :current_yaml, :string
  end

  object :config_apply_result do
    field :changed, non_null(:boolean)
    field :resource, non_null(:config_resource)
  end

  object :dashboard do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :title, non_null(:string)
    field :workspace, non_null(:string)
    field :spec, non_null(:json)
    field :is_default, non_null(:boolean)
    field :shared, non_null(:boolean), resolve: fn d, _, _ -> {:ok, is_nil(d.owner_id)} end
    field :lock_version, non_null(:integer)
    field :updated_at, :datetime
  end

  object :widget_type do
    field :type, non_null(:string)
    field :context, non_null(:string)
    field :min_width, non_null(:integer), resolve: fn w, _, _ -> {:ok, elem(w.min, 0)} end
    field :min_height, non_null(:integer), resolve: fn w, _, _ -> {:ok, elem(w.min, 1)} end
    field :permission, non_null(:string)
    field :refresh, non_null(:string)
    field :workspaces, non_null(list_of(non_null(:string)))
  end

  object :alert_policy do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :event_types, non_null(list_of(non_null(:string)))
    field :severity, non_null(:string)
    field :cooldown_seconds, non_null(:integer)
    field :destinations, :json
    field :enabled, non_null(:boolean)
  end

  object :alert_delivery do
    field :id, non_null(:id)
    field :destination, non_null(:string)
    field :kind, non_null(:string)
    field :status, non_null(:string)
    field :attempts, non_null(:integer)
    field :last_error, :string
    field :response_status, :integer
    field :delivered_at, :datetime
    field :updated_at, :datetime
  end

  object :alert_occurrence do
    field :id, non_null(:id)
    field :fingerprint, non_null(:string)
    field :state, non_null(:string)
    field :severity, non_null(:string)
    field :title, non_null(:string)
    field :details, :json
    field :count, non_null(:integer)
    field :first_seen_at, non_null(:datetime)
    field :last_seen_at, non_null(:datetime)
    field :resolved_at, :datetime
    field :policy_name, :string, resolve: fn o, _, _ -> {:ok, o.policy && o.policy.name} end
    field :deliveries, non_null(list_of(non_null(:alert_delivery)))
  end

  object :overview do
    field :confirmed_sats, non_null(:sats)
    field :pending_sats, non_null(:sats)
    field :utxo_count, non_null(:integer)
    field :tip_height, :integer
    field :tip_hash, :string
    field :tip_time, :datetime
    field :mempool_size, non_null(:integer)
    field :open_discrepancies, non_null(:integer)
    field :last_reconciliation, :reconciliation_run
    field :active_experiments, non_null(list_of(non_null(:experiment_run)))
    field :recent_experiments, non_null(list_of(non_null(:experiment_run)))
    field :firing_alerts, non_null(:integer)
    field :ingestion_lag_blocks, :integer
    field :ingestion_latency_ms, :integer
  end

  object :operations_queries do
    field :overview, non_null(:overview) do
      arg :environment_id, non_null(:id)
      middleware Authorize, {:"environment.read", :environment_id}

      resolve fn %{environment_id: env_id}, _ ->
        env = Environments.get!(env_id)
        bal = WalletMonitoring.balance(env_id, env.required_confirmations)
        tip = Blockchain.tip(env_id)
        obs = Blockchain.latest_observations(env_id) |> Enum.map(&elem(&1, 1)) |> Enum.reject(&is_nil/1)

        node_height =
          obs
          |> Enum.filter(& &1.reachable)
          |> Enum.map(& &1.height)
          |> Enum.reject(&is_nil/1)
          |> Enum.max(fn -> nil end)

        latencies = obs |> Enum.map(& &1.rpc_latency_ms) |> Enum.reject(&is_nil/1)

        {:ok,
         %{
           confirmed_sats: bal.confirmed_sats,
           pending_sats: bal.pending_sats,
           utxo_count: bal.utxo_count,
           tip_height: tip && tip.height,
           tip_hash: tip && tip.hash,
           tip_time: tip && tip.block_time,
           mempool_size: Blockchain.mempool_size(env_id),
           open_discrepancies: Reconciliation.open_count(env_id),
           last_reconciliation: List.first(Reconciliation.list_runs(env_id, 1)),
           active_experiments:
             Experiments.list_runs(env_id,
               statuses: ~w(created validating provisioning preparing running verifying cleaning_up),
               limit: 10
             ),
           recent_experiments:
             Experiments.list_runs(env_id, statuses: ~w(passed failed inconclusive aborted), limit: 10),
           firing_alerts: length(Alerts.list_occurrences(env_id, state: "firing", limit: 200)),
           ingestion_lag_blocks: node_height && tip && max(node_height - tip.height, 0),
           ingestion_latency_ms: if(latencies == [], do: nil, else: Enum.max(latencies))
         }}
      end
    end

    field :scenarios, non_null(list_of(non_null(:scenario))) do
      middleware Authorize, :"experiment.read"
      resolve fn _, _ -> {:ok, Experiments.list_scenarios()} end
    end

    field :scenario, :scenario do
      arg :id, non_null(:id)
      middleware Authorize, :"experiment.read"
      resolve fn %{id: id}, _ -> wrap(Experiments.get_scenario(id)) end
    end

    field :experiment_runs, non_null(list_of(non_null(:experiment_run))) do
      arg :environment_id, non_null(:id)
      arg :limit, :integer, default_value: 30
      middleware Authorize, {:"experiment.read", :environment_id}
      resolve fn a, _ -> {:ok, Experiments.list_runs(a.environment_id, limit: a.limit)} end
    end

    field :experiment_run, :experiment_run do
      arg :id, non_null(:id)

      resolve fn %{id: id}, res ->
        with %{} = run <- Experiments.get_run(id), :ok <- authorize_env(res, :"experiment.read", run.environment_id) do
          {:ok, run}
        else
          nil -> {:error, :not_found}
          e -> e
        end
      end
    end

    field :experiment_actions, non_null(list_of(non_null(:action_descriptor))) do
      resolve fn _, _ -> {:ok, Experiments.actions()} end
    end

    field :runtime_capabilities, non_null(list_of(non_null(:string))) do
      arg :environment_id, non_null(:id)
      middleware Authorize, {:"experiment.read", :environment_id}
      resolve fn a, _ -> {:ok, Experiments.capabilities(a.environment_id)} end
    end

    field :config_resources, non_null(list_of(non_null(:config_resource))) do
      arg :kind, :string
      middleware Authorize, :"config.read"
      resolve fn a, _ -> {:ok, Configuration.list(kind: a[:kind])} end
    end

    field :config_resource, :config_resource do
      arg :kind, non_null(:string)
      arg :name, non_null(:string)
      middleware Authorize, :"config.read"
      resolve fn a, _ -> {:ok, Configuration.get(a.kind, a.name)} end
    end

    field :config_schema, non_null(:json) do
      arg :kind, non_null(:string)
      middleware Authorize, :"config.read"

      resolve fn %{kind: kind}, _ ->
        if kind in Configuration.kinds(), do: {:ok, Schemas.raw(kind)}, else: {:error, :not_found}
      end
    end

    field :dashboards, non_null(list_of(non_null(:dashboard))) do
      arg :workspace, non_null(:string)
      middleware Authorize, :"dashboard.read"
      resolve fn a, res -> {:ok, Dashboards.list_for(actor(res), a.workspace)} end
    end

    field :widget_types, non_null(list_of(non_null(:widget_type))) do
      resolve fn _, _ -> {:ok, Dashboards.widget_types()} end
    end

    field :alert_policies, non_null(list_of(non_null(:alert_policy))) do
      arg :environment_id, non_null(:id)
      middleware Authorize, {:"alert.read", :environment_id}
      resolve fn a, _ -> {:ok, Alerts.list_policies(a.environment_id)} end
    end

    field :alerts, non_null(list_of(non_null(:alert_occurrence))) do
      arg :environment_id, non_null(:id)
      arg :state, :string
      arg :limit, :integer, default_value: 50
      middleware Authorize, {:"alert.read", :environment_id}
      resolve fn a, _ -> {:ok, Alerts.list_occurrences(a.environment_id, state: a[:state], limit: a.limit)} end
    end
  end

  input_object :alert_policy_input do
    field :name, non_null(:string)
    field :event_types, non_null(list_of(non_null(:string)))
    field :severity, :string
    field :cooldown_seconds, :integer
    field :destinations, :json
    field :enabled, :boolean
  end

  object :operations_mutations do
    field :start_experiment, :experiment_run do
      arg :environment_id, non_null(:id)
      arg :scenario_id, non_null(:id)
      arg :seed, :integer
      middleware Authorize, {:"experiment.run", :environment_id}

      resolve fn a, res ->
        params = if a[:seed], do: %{"seed" => a.seed}, else: %{}
        Experiments.start_run(a.environment_id, a.scenario_id, params, actor(res))
      end
    end

    field :abort_experiment, :experiment_run do
      arg :id, non_null(:id)

      resolve fn %{id: id}, res ->
        with %{} = run <- Experiments.get_run(id),
             :ok <- authorize_env(res, :"experiment.run", run.environment_id) do
          Experiments.abort_run(run, actor(res))
        else
          nil -> {:error, :not_found}
          e -> e
        end
      end
    end

    field :validate_config, non_null(:config_validation) do
      arg :yaml, :string
      arg :document, :json
      middleware Authorize, :"config.read"

      resolve fn a, _ ->
        result =
          cond do
            is_binary(a[:yaml]) -> Configuration.parse(a.yaml)
            is_map(a[:document]) -> Configuration.validate(a.document)
            true -> {:error, [%{message: "yaml or document is required"}]}
          end

        case result do
          {:ok, doc} -> {:ok, %{valid: true, document: doc, canonical_yaml: Yaml.encode(doc), errors: []}}
          {:error, errors} -> {:ok, %{valid: false, document: nil, canonical_yaml: nil, errors: errors}}
        end
      end
    end

    field :plan_config, :config_plan do
      arg :document, non_null(:json)
      middleware Authorize, :"config.read"
      resolve fn a, _ -> Configuration.plan(a.document) end
    end

    field :apply_config, :config_apply_result do
      arg :document, non_null(:json)
      arg :expected_revision, :integer
      arg :message, :string
      middleware Authorize, :"config.apply"

      resolve fn a, res ->
        Configuration.apply_document(a.document,
          actor: actor(res),
          expected_revision: a[:expected_revision],
          message: a[:message]
        )
      end
    end

    field :reapply_config, :config_apply_result do
      arg :kind, non_null(:string)
      arg :name, non_null(:string)
      arg :revision, non_null(:integer)
      middleware Authorize, :"config.apply"

      resolve fn a, res ->
        case Configuration.get(a.kind, a.name) do
          nil -> {:error, :not_found}
          r -> Configuration.reapply_revision(r, a.revision, actor(res))
        end
      end
    end

    field :delete_config, :boolean do
      arg :kind, non_null(:string)
      arg :name, non_null(:string)
      middleware Authorize, :"config.apply"

      resolve fn a, res ->
        case Configuration.get(a.kind, a.name) do
          nil -> {:error, :not_found}
          r -> with {:ok, _} <- Configuration.delete(r, actor(res)), do: {:ok, true}
        end
      end
    end

    field :save_dashboard, :dashboard do
      arg :name, non_null(:string)
      arg :spec, non_null(:json)
      arg :lock_version, :integer
      middleware Authorize, :"dashboard.manage"

      resolve fn a, res ->
        user = actor(res)
        Dashboards.save_personal(user, %{"name" => a.name, "spec" => a.spec, "lockVersion" => a[:lock_version]}, user)
      end
    end

    field :delete_dashboard, :boolean do
      arg :id, non_null(:id)
      middleware Authorize, :"dashboard.manage"

      resolve fn a, res ->
        case Dashboards.get(a.id) do
          nil -> {:error, :not_found}
          d -> with {:ok, _} <- Dashboards.delete(d, actor(res)), do: {:ok, true}
        end
      end
    end

    field :restore_default_dashboard, :dashboard do
      arg :workspace, non_null(:string)
      middleware Authorize, :"dashboard.manage"
      resolve fn a, res -> Dashboards.restore_default(actor(res), a.workspace) end
    end

    field :save_alert_policy, :alert_policy do
      arg :environment_id, non_null(:id)
      arg :input, non_null(:alert_policy_input)
      middleware Authorize, {:"alert.manage", :environment_id}
      resolve fn a, res -> Alerts.upsert_policy(a.environment_id, a.input, actor(res)) end
    end

    field :delete_alert_policy, :boolean do
      arg :id, non_null(:id)

      resolve fn a, res ->
        with %{} = p <- Alerts.get_policy(a.id),
             :ok <- authorize_env(res, :"alert.manage", p.environment_id),
             {:ok, _} <- Alerts.delete_policy(p, actor(res)) do
          {:ok, true}
        else
          nil -> {:error, :not_found}
          e -> e
        end
      end
    end

    field :update_alert, :alert_occurrence do
      arg :id, non_null(:id)
      arg :action, non_null(:string)

      resolve fn a, res ->
        with %{} = o <- Alerts.get_occurrence(a.id),
             :ok <- authorize_env(res, :"alert.manage", o.environment_id) do
          case a.action do
            "acknowledge" -> Alerts.acknowledge(o, actor(res))
            "resolve" -> Alerts.resolve(o, actor(res))
            _ -> {:error, "action must be acknowledge or resolve"}
          end
          |> case do
            {:ok, _} -> {:ok, Alerts.get_occurrence(o.id)}
            e -> e
          end
        else
          nil -> {:error, :not_found}
          e -> e
        end
      end
    end

    field :retry_alert_delivery, :boolean do
      arg :id, non_null(:id)
      middleware Authorize, :"alert.manage"
      resolve fn a, res -> with({:ok, _} <- Alerts.retry_delivery(a.id, actor(res)), do: {:ok, true}) end
    end
  end
end
