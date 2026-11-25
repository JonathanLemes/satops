defmodule SatOps.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias SatOps.Repo
      import Ecto.Query
      import SatOps.DataCase
      import SatOps.Factory
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(SatOps.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end

defmodule SatOps.CommittedCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias SatOps.Repo
      import Ecto.Query
      import SatOps.Factory
      @moduletag :integration
    end
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(SatOps.Repo, :auto)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.mode(SatOps.Repo, :manual) end)
    :ok
  end
end

defmodule SatOps.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint SatOpsWeb.Endpoint
      import Plug.Conn
      import Phoenix.ConnTest
      import SatOps.ConnCase
      import SatOps.Factory
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(SatOps.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def login(conn, user) do
    {token, session} = SatOps.Identity.create_session(user)

    conn
    |> Plug.Test.put_req_cookie("satops_session", token)
    |> Plug.Conn.put_req_header("x-csrf-token", session.csrf_token)
  end

  def gql(conn, query, variables \\ %{}) do
    conn
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Phoenix.ConnTest.dispatch(
      SatOpsWeb.Endpoint,
      :post,
      "/graphql",
      Jason.encode!(%{query: query, variables: variables})
    )
    |> Phoenix.ConnTest.json_response(200)
  end
end
