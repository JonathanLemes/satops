defmodule SatOpsWeb.GraphQL.Types.Platform do
  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers, only: [dataloader: 1]
  import SatOpsWeb.GraphQL.Helpers
  alias SatOps.{Audit, Environments, Events, Identity, Integrations, Repo, Secrets}
  alias SatOpsWeb.GraphQL.Authorize

  object :user do
    field :id, non_null(:id)
    field :email, non_null(:string)
    field :name, non_null(:string)
    field :role, non_null(:string)
    field :locale, non_null(:string)
    field :disabled_at, :datetime
    field :inserted_at, :datetime
  end

  object :environment do
    field :id, non_null(:id)
    field :slug, non_null(:string)
    field :name, non_null(:string)
    field :kind, non_null(:string)
    field :network, non_null(:string)
    field :status, non_null(:string)
    field :required_confirmations, non_null(:integer)
    field :settings, :json
    field :inserted_at, :datetime
  end

  object :integration do
    field :id, non_null(:id)
    field :environment_id, non_null(:id)
    field :name, non_null(:string)
    field :kind, non_null(:string)
    field :config, :json
    field :secret_ref, :string
    field :enabled, non_null(:boolean)
    field :status, non_null(:string)
    field :health, :json
    field :capabilities, non_null(list_of(non_null(:string)))
    field :enabled_operations, list_of(:string)
    field :retry, :json
    field :checkpoint, :json
    field :last_sync_at, :datetime
    field :last_error, :string
    field :lock_version, non_null(:integer)
    field :updated_at, :datetime

    field :errors, non_null(list_of(non_null(:integration_error))) do
      resolve fn i, _, _ -> {:ok, Integrations.errors(i.id)} end
    end
  end

  object :integration_error do
    field :message, non_null(:string)
    field :occurred_at, non_null(:datetime)
  end

  object :connection_test do
    field :ok, non_null(:boolean)
    field :status, non_null(:string)
    field :details, :json
    field :error, :string
  end

  object :audit_entry do
    field :id, non_null(:id)
    field :actor_email, :string
    field :action, non_null(:string)
    field :environment_id, :id
    field :resource_type, :string
    field :resource_id, :string
    field :changes, :json
    field :ip, :string
    field :correlation_id, :id
    field :inserted_at, non_null(:datetime)
  end

  object :domain_event do
    field :id, non_null(:id)
    field :seq, non_null(:integer)
    field :event_type, non_null(:string)
    field :schema_version, non_null(:integer)
    field :environment_id, non_null(:id)
    field :network_id, :string
    field :aggregate_type, non_null(:string)
    field :aggregate_id, non_null(:string)
    field :aggregate_version, :integer
    field :occurred_at, non_null(:datetime)
    field :observed_at, non_null(:datetime)
    field :correlation_id, non_null(:id)
    field :causation_id, :id
    field :payload, :json
  end

  object :consumer_checkpoint do
    field :consumer, non_null(:string)
    field :last_seq, non_null(:integer)
    field :lag, non_null(:integer)
    field :updated_at, :datetime
  end

  object :job_stat do
    field :queue, non_null(:string)
    field :state, non_null(:string)
    field :count, non_null(:integer)
  end

  object :job do
    field :id, non_null(:id)
    field :queue, non_null(:string)
    field :worker, non_null(:string)
    field :state, non_null(:string)
    field :attempt, non_null(:integer)
    field :max_attempts, non_null(:integer)
    field :errors, :json
    field :inserted_at, :datetime
    field :attempted_at, :datetime
    field :completed_at, :datetime
  end

  input_object :integration_input do
    field :name, non_null(:string)
    field :kind, non_null(:string)
    field :config, non_null(:json)
    field :secret_ref, :string
    field :enabled, :boolean
    field :lock_version, :integer
  end

  object :platform_queries do
    field :environments, non_null(list_of(non_null(:environment))) do
      resolve fn _, _, res -> {:ok, Environments.list(Identity.environment_ids_for(actor(res)))} end
    end

    field :environment, :environment do
      arg :id, non_null(:id)
      middleware Authorize, {:"environment.read", {:arg, :id}}
      resolve fn %{id: id}, _ -> wrap(Environments.get(id)) end
    end

    field :integrations, non_null(list_of(non_null(:integration))) do
      arg :environment_id, non_null(:id)
      arg :kind, :string
      middleware Authorize, {:"environment.read", :environment_id}
      resolve fn args, _ -> {:ok, Integrations.list(args.environment_id, kind: args[:kind])} end
    end

    field :integration, :integration do
      arg :id, non_null(:id)

      resolve fn %{id: id}, res ->
        with %{} = i <- Integrations.get(id), :ok <- authorize_env(res, :"integration.read", i.environment_id) do
          {:ok, i}
        else
          nil -> {:error, :not_found}
          error -> error
        end
      end
    end

    field :integration_kinds, non_null(list_of(non_null(:string))) do
      resolve fn _, _ -> {:ok, Integrations.kinds()} end
    end

    field :secret_names, non_null(list_of(non_null(:string))) do
      arg :environment_id, non_null(:id)
      middleware Authorize, {:"integration.read", :environment_id}
      resolve fn args, _ -> {:ok, Secrets.names(args.environment_id)} end
    end

    field :audit_log, non_null(list_of(non_null(:audit_entry))) do
      arg :environment_id, :id
      arg :action, :string
      arg :resource_id, :string
      arg :correlation_id, :id
      arg :before_id, :integer
      arg :limit, :integer, default_value: 100
      middleware Authorize, {:"audit.read", :environment_id}
      resolve fn args, _ -> {:ok, Audit.list(Map.drop(args, [:limit]), args.limit)} end
    end

    field :events, non_null(list_of(non_null(:domain_event))) do
      arg :environment_id, non_null(:id)
      arg :types, list_of(non_null(:string))
      arg :aggregate_id, :string
      arg :correlation_id, :id
      arg :before_seq, :integer
      arg :limit, :integer, default_value: 50
      middleware Authorize, {:"blockchain.read", :environment_id}
      resolve fn args, _ -> {:ok, Events.list(args.environment_id, Map.to_list(Map.drop(args, [:environment_id])))} end
    end

    field :event_consumers, non_null(list_of(non_null(:consumer_checkpoint))) do
      middleware Authorize, :"jobs.read"

      resolve fn _, _ ->
        head = Events.head_seq()
        known = Events.checkpoints() |> Map.new(&{&1.consumer, &1})

        {:ok,
         Enum.map(Events.consumers(), fn c ->
           cp = Map.get(known, c.name(), %{last_seq: 0, updated_at: nil})
           %{consumer: c.name(), last_seq: cp.last_seq, lag: max(head - cp.last_seq, 0), updated_at: cp.updated_at}
         end)}
      end
    end

    field :job_stats, non_null(list_of(non_null(:job_stat))) do
      middleware Authorize, :"jobs.read"

      resolve fn _, _ ->
        %{rows: rows} =
          Repo.query!("SELECT queue, state, count(*) FROM oban_jobs GROUP BY queue, state ORDER BY queue, state")

        {:ok, Enum.map(rows, fn [q, s, c] -> %{queue: q, state: s, count: c} end)}
      end
    end

    field :jobs, non_null(list_of(non_null(:job))) do
      arg :state, :string
      arg :queue, :string
      arg :limit, :integer, default_value: 50
      middleware Authorize, :"jobs.read"

      resolve fn args, _ ->
        import Ecto.Query

        {:ok,
         Oban.Job
         |> then(fn q -> if s = args[:state], do: where(q, [j], j.state == ^s), else: q end)
         |> then(fn q -> if qu = args[:queue], do: where(q, [j], j.queue == ^qu), else: q end)
         |> order_by([j], desc: j.id)
         |> limit(^min(args.limit, 200))
         |> Repo.all()
         |> Enum.map(fn j -> %{j | errors: SatOps.Redactor.redact(j.errors)} end)}
      end
    end

    field :users, non_null(list_of(non_null(:user))) do
      middleware Authorize, :"user.manage"
      resolve fn _, _ -> {:ok, Identity.list_users()} end
    end
  end

  object :platform_mutations do
    field :create_environment, :environment do
      arg :slug, non_null(:string)
      arg :name, non_null(:string)
      arg :required_confirmations, :integer
      middleware Authorize, :"environment.manage"

      resolve fn args, res ->
        Environments.create(
          Map.put(args, :settings, %{"safety" => %{"allowMainnet" => false, "allowPublicPeers" => false}}),
          actor(res)
        )
      end
    end

    field :save_integration, :integration do
      arg :environment_id, non_null(:id)
      arg :input, non_null(:integration_input)
      middleware Authorize, {:"integration.manage", :environment_id}

      resolve fn %{environment_id: env, input: input}, res ->
        attrs =
          Map.take(input, [:kind, :config, :secret_ref, :enabled])
          |> Map.put(:environment_id, env)
          |> Map.put(:name, input.name)

        case Integrations.get_by_name(env, input.name) do
          nil ->
            Integrations.create(attrs, actor(res))

          existing ->
            if input[:lock_version] && input.lock_version != existing.lock_version,
              do: {:error, :stale},
              else: Integrations.update(existing, attrs, actor(res))
        end
      end
    end

    field :delete_integration, :boolean do
      arg :id, non_null(:id)

      resolve fn %{id: id}, res ->
        with %{} = i <- Integrations.get(id),
             :ok <- authorize_env(res, :"integration.manage", i.environment_id),
             {:ok, _} <- Integrations.delete(i, actor(res)) do
          {:ok, true}
        else
          nil -> {:error, :not_found}
          error -> error
        end
      end
    end

    field :test_integration, :connection_test do
      arg :id, non_null(:id)

      resolve fn %{id: id}, res ->
        with %{} = i <- Integrations.get(id), :ok <- authorize_env(res, :"integration.read", i.environment_id) do
          Audit.record!(actor(res), "integration.tested", resource: i)

          case Integrations.test_connection(i) do
            {:ok, details} ->
              {:ok, %{ok: true, status: "healthy", details: details, error: nil}}

            {:error, reason} ->
              {:ok, %{ok: false, status: "unavailable", details: nil, error: Integrations.format_error(reason)}}
          end
        else
          nil -> {:error, :not_found}
          error -> error
        end
      end
    end

    field :put_secret, :boolean do
      arg :environment_id, non_null(:id)
      arg :name, non_null(:string)
      arg :value, non_null(:string)
      middleware Authorize, {:"secret.manage", :environment_id}

      resolve fn args, res ->
        if Regex.match?(~r/^[a-z0-9][a-z0-9-_.]{0,62}$/, args.name) do
          :ok = Secrets.put(args.environment_id, args.name, args.value)

          Audit.record!(actor(res), "secret.updated",
            environment_id: args.environment_id,
            resource_type: "secret",
            resource_id: args.name
          )

          {:ok, true}
        else
          {:error, "secret names use lowercase letters, digits, dot, dash and underscore"}
        end
      end
    end

    field :create_user, :user do
      arg :email, non_null(:string)
      arg :name, non_null(:string)
      arg :role, non_null(:string)
      arg :password, non_null(:string)
      arg :environment_id, :id
      middleware Authorize, :"user.manage"

      resolve fn args, res ->
        Repo.transaction(fn ->
          with {:ok, user} <- Identity.create_user(Map.take(args, [:email, :name, :role, :password]), actor(res)),
               {:ok, _} <- maybe_membership(user, args[:environment_id], args.role, actor(res)) do
            user
          else
            {:error, reason} -> Repo.rollback(reason)
          end
        end)
      end
    end

    field :update_user, :user do
      arg :id, non_null(:id)
      arg :role, :string
      arg :disabled, :boolean
      middleware Authorize, :"user.manage"

      resolve fn args, res ->
        with %{} = user <- Identity.get_user(args.id) do
          attrs =
            %{}
            |> then(fn a -> if args[:role], do: Map.put(a, :role, args.role), else: a end)
            |> then(fn a ->
              if is_boolean(args[:disabled]),
                do: Map.put(a, :disabled_at, if(args.disabled, do: DateTime.utc_now())),
                else: a
            end)

          Identity.update_user(user, attrs, actor(res))
        else
          nil -> {:error, :not_found}
        end
      end
    end

    field :set_membership, :boolean do
      arg :user_id, non_null(:id)
      arg :environment_id, non_null(:id)
      arg :role, non_null(:string)
      middleware Authorize, :"user.manage"

      resolve fn args, res ->
        with {:ok, _} <- Identity.put_membership(args.user_id, args.environment_id, args.role, actor(res)),
             do: {:ok, true}
      end
    end

    field :update_locale, :user do
      arg :locale, non_null(:string)

      resolve fn %{locale: locale}, res ->
        user = actor(res)
        if user, do: Identity.update_user(user, %{locale: locale}, user), else: {:error, :unauthenticated}
      end
    end

    field :replay_events, :boolean do
      arg :consumer, non_null(:string)
      arg :from_seq, non_null(:integer)
      middleware Authorize, :"config.apply"

      resolve fn args, res ->
        case Events.replay(args.consumer, args.from_seq) do
          {:ok, _} ->
            Audit.record!(actor(res), "events.replay_requested",
              resource_type: "consumer",
              resource_id: args.consumer,
              changes: %{from_seq: args.from_seq}
            )

            {:ok, true}

          error ->
            error
        end
      end
    end
  end

  defp maybe_membership(_user, nil, _role, _actor), do: {:ok, nil}
  defp maybe_membership(user, env_id, role, actor), do: Identity.put_membership(user.id, env_id, role, actor)

  def loader, do: dataloader(:repo)
end
