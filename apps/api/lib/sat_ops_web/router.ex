defmodule SatOpsWeb.Router do
  use SatOpsWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :session do
    plug SatOpsWeb.Plugs.Auth
    plug SatOpsWeb.Plugs.CSRF
  end

  pipeline :authenticated do
    plug SatOpsWeb.Plugs.RequireAuth
  end

  pipeline :graphql do
    plug SatOpsWeb.Plugs.GraphQLContext
  end

  get "/metrics", SatOpsWeb.HealthController, :metrics

  scope "/api", SatOpsWeb do
    get "/health", HealthController, :live
    get "/ready", HealthController, :ready
    post "/webhooks/:environment/:integration", WebhookController, :receive
  end

  scope "/api", SatOpsWeb do
    pipe_through [:api, :session]
    post "/auth/login", AuthController, :login
    post "/auth/logout", AuthController, :logout
    get "/auth/me", AuthController, :me
  end

  scope "/api", SatOpsWeb do
    pipe_through [:session, :authenticated]
    post "/auth/password", AuthController, :password
    post "/imports/csv/:integration_id", ImportController, :csv
    get "/reports/experiments/:id", ReportController, :experiment
    get "/reports/reconciliation/:id", ReportController, :reconciliation
    get "/config/:kind/:name/export", ReportController, :config
  end

  scope "/" do
    pipe_through [:session, :authenticated, :graphql]

    forward "/graphql", Absinthe.Plug,
      schema: SatOpsWeb.GraphQL.Schema,
      analyze_complexity: true,
      max_complexity: 2_000,
      token_limit: 4_000,
      json_codec: Jason
  end
end
