defmodule SatOpsWeb.ApiTest do
  use SatOps.ConnCase

  test "login sets an HttpOnly session cookie and returns permissions", %{conn: conn} do
    u = user("engineer")
    conn = post(conn, "/api/auth/login", %{email: u.email, password: "correct-horse-battery"})
    body = json_response(conn, 200)
    assert body["user"]["email"] == u.email
    assert "experiment.run" in body["permissions"]
    cookie = conn.resp_cookies["satops_session"]
    assert cookie.http_only and cookie.same_site == "Strict"
  end

  test "wrong credentials are rejected with a generic message", %{conn: conn} do
    u = user()

    assert %{"error" => "invalid_credentials"} =
             conn |> post("/api/auth/login", %{email: u.email, password: "nope-nope-nope"}) |> json_response(401)

    assert %{"error" => "invalid_credentials"} =
             build_conn()
             |> post("/api/auth/login", %{email: "ghost@x.test", password: "nope-nope-nope"})
             |> json_response(401)
  end

  test "GraphQL requires authentication and a CSRF token for mutations", %{conn: conn} do
    assert conn
           |> put_req_header("content-type", "application/json")
           |> post("/graphql", Jason.encode!(%{query: "{ me { id } }"}))
           |> response(401)

    u = user()
    {token, _session} = SatOps.Identity.create_session(u)

    resp =
      build_conn()
      |> Plug.Test.put_req_cookie("satops_session", token)
      |> put_req_header("content-type", "application/json")
      |> post("/graphql", Jason.encode!(%{query: "mutation { updateLocale(locale: \"pt-BR\") { locale } }"}))

    assert resp.status == 403
  end

  test "viewers cannot run experiments or read the audit log", %{conn: conn} do
    env = environment()
    viewer = user("viewer")
    {:ok, _} = SatOps.Identity.put_membership(viewer.id, env.id, "viewer", nil)
    conn = login(conn, viewer)

    r = gql(conn, "query($e: ID!) { auditLog(environmentId: $e) { id } }", %{"e" => env.id})
    assert [%{"extensions" => %{"code" => "FORBIDDEN"}}] = r["errors"]

    r =
      gql(
        login(build_conn(), viewer),
        "query($e: ID!) { overview(environmentId: $e) { confirmedSats openDiscrepancies } }",
        %{"e" => env.id}
      )

    assert r["data"]["overview"]["confirmedSats"] == 0
  end

  test "users without membership cannot read another environment", %{conn: conn} do
    env = environment()
    eng = user("engineer")
    r = gql(login(conn, eng), "query($e: ID!) { integrations(environmentId: $e) { id } }", %{"e" => env.id})
    assert [%{"extensions" => %{"code" => "FORBIDDEN"}}] = r["errors"]
  end

  test "config validation via GraphQL returns precise errors and canonical YAML", %{conn: conn} do
    conn = login(conn, user())

    yaml =
      "apiVersion: satops.io/v1alpha1\nkind: Environment\nmetadata:\n  name: x\nspec:\n  network:\n    type: regtest\n    type: mainnet\n"

    r = gql(conn, "mutation($y: String) { validateConfig(yaml: $y) { valid errors { message line } } }", %{"y" => yaml})

    assert %{"valid" => false, "errors" => [%{"message" => "duplicate key \"type\"", "line" => 8}]} =
             r["data"]["validateConfig"]
  end

  test "webhooks require a valid signature and are deduplicated", %{conn: conn} do
    env = environment()
    :ok = SatOps.Secrets.put(env.id, "hook-secret", "s3cret")

    {:ok, _} =
      SatOps.Integrations.create(
        %{
          environment_id: env.id,
          name: "hooks",
          kind: "webhook_receiver",
          config: %{"webhookSecretRef" => "hook-secret"}
        },
        nil
      )

    body =
      Jason.encode!(%{
        record: %{
          id: "r1",
          kind: "deposit",
          customerId: "c1",
          amountSats: 1000,
          txid: "aa",
          vout: 0,
          status: "credited"
        }
      })

    ts = System.system_time(:second)
    sig = :crypto.mac(:hmac, :sha256, "s3cret", "#{ts}.#{body}") |> Base.encode16(case: :lower)

    send_hook = fn signature ->
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-satops-signature", signature)
      |> put_req_header("x-satops-delivery", "d-1")
      |> post("/api/webhooks/#{env.slug}/hooks", body)
    end

    assert send_hook.("t=#{ts},v1=deadbeef").status == 401
    assert send_hook.("t=#{ts},v1=#{sig}").status == 202
    assert send_hook.("t=#{ts},v1=#{sig}").status == 200
    old = ts - 3600
    old_sig = :crypto.mac(:hmac, :sha256, "s3cret", "#{old}.#{body}") |> Base.encode16(case: :lower)
    assert send_hook.("t=#{old},v1=#{old_sig}").status == 401
    _ = conn
  end
end
