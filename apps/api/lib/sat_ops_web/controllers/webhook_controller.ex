defmodule SatOpsWeb.WebhookController do
  use SatOpsWeb, :controller
  alias SatOps.{Environments, Identity.RateLimiter, Integrations}

  def receive(conn, %{"environment" => env_slug, "integration" => name}) do
    with :ok <- RateLimiter.hit({:webhook, env_slug, name}, 600, 60_000),
         %{} = env <- Environments.get_by_slug(env_slug),
         %{} = integration <- Integrations.get_by_name(env.id, name),
         true <- "webhooks.inbound" in integration.capabilities || :not_supported do
      body = conn.assigns[:raw_body] || ""

      case Integrations.receive_webhook(integration, conn.req_headers, body) do
        {:ok, :accepted} -> conn |> put_status(202) |> json(%{status: "accepted"})
        {:ok, :duplicate} -> conn |> put_status(200) |> json(%{status: "duplicate"})
        {:error, :timestamp_out_of_tolerance} -> error(conn, 401, "stale_signature")
        {:error, :invalid_signature} -> error(conn, 401, "invalid_signature")
        {:error, :webhook_not_configured} -> error(conn, 404, "not_found")
        {:error, %Jason.DecodeError{}} -> error(conn, 400, "invalid_json")
        {:error, _} -> error(conn, 400, "rejected")
      end
    else
      {:error, :rate_limited} -> error(conn, 429, "rate_limited")
      _ -> error(conn, 404, "not_found")
    end
  end
end
