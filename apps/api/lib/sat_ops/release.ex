defmodule SatOps.Release do
  require Logger
  @app :sat_ops

  def migrate do
    load_app()

    for repo <- Application.fetch_env!(@app, :ecto_repos) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def bootstrap do
    SatOps.Secrets.bootstrap_from_env()
    env = SatOps.Environments.ensure_default()
    SatOps.Seeds.ensure_platform_defaults(env)
    :ok
  rescue
    error ->
      Logger.error("bootstrap failed: #{Exception.message(error)}")
      :error
  end

  def create_admin(email, name \\ "Administrator") do
    start_app()
    password = Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)

    case SatOps.Identity.create_user(%{email: email, name: name, password: password, role: "administrator"}) do
      {:ok, user} ->
        IO.puts("Administrator #{user.email} created. Temporary password (shown once): #{password}")
        :ok

      {:error, changeset} ->
        IO.puts("Could not create administrator: #{inspect(changeset.errors)}")
        :error
    end
  end

  def create_user(email, name, role) do
    start_app()
    password = Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)
    env = SatOps.Environments.ensure_default()

    with {:ok, user} <- SatOps.Identity.create_user(%{email: email, name: name, password: password, role: role}),
         {:ok, _} <- SatOps.Identity.put_membership(user.id, env.id, role, nil) do
      IO.puts("User #{user.email} (#{role}) created. Temporary password (shown once): #{password}")
    end
  end

  defp start_app do
    load_app()
    Application.ensure_all_started(@app)
  end

  defp load_app do
    Application.ensure_loaded(@app)
  end
end
