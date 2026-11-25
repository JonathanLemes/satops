defmodule SatOpsWeb.GraphQL.Schema do
  use Absinthe.Schema

  import_types Absinthe.Type.Custom
  import_types SatOpsWeb.GraphQL.Scalars
  import_types SatOpsWeb.GraphQL.Types.Platform
  import_types SatOpsWeb.GraphQL.Types.Blockchain
  import_types SatOpsWeb.GraphQL.Types.Finance
  import_types SatOpsWeb.GraphQL.Types.Operations

  query do
    field :me, :user do
      resolve fn _, %{context: ctx} -> {:ok, ctx[:current_user]} end
    end

    import_fields :platform_queries
    import_fields :blockchain_queries
    import_fields :finance_queries
    import_fields :operations_queries
  end

  mutation do
    import_fields :platform_mutations
    import_fields :blockchain_mutations
    import_fields :finance_mutations
    import_fields :operations_mutations
  end

  def context(ctx), do: Map.put(ctx, :loader, ctx[:loader] || SatOpsWeb.GraphQL.Loader.new())

  def plugins, do: [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]

  def middleware(middleware, _field, %{identifier: type}) when type in [:query, :mutation] do
    [SatOpsWeb.GraphQL.RequireUser | middleware] ++ [SatOpsWeb.GraphQL.Errors]
  end

  def middleware(middleware, _field, _object), do: middleware
end

defmodule SatOpsWeb.GraphQL.RequireUser do
  @behaviour Absinthe.Middleware

  def call(%{context: %{current_user: %{}}} = res, _), do: res

  def call(res, _) do
    Absinthe.Resolution.put_result(res, {:error, message: "unauthenticated", extensions: %{code: "UNAUTHENTICATED"}})
  end
end
