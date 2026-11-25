defmodule SatOps.Integrations.Http do
  alias SatOps.Integrations.UrlPolicy

  def request(method, url, opts \\ []) do
    with {:ok, _} <- UrlPolicy.validate_url(url) do
      max_attempts = Keyword.get(opts, :max_attempts, 3)
      timeout = Keyword.get(opts, :timeout, 5_000)

      Req.request(
        method: method,
        url: url,
        headers: Keyword.get(opts, :headers, []),
        json: opts[:json],
        body: opts[:body],
        params: opts[:params],
        receive_timeout: timeout,
        connect_options: [timeout: min(timeout, 3_000)],
        redirect: false,
        retry: if(max_attempts > 1 and method == :get, do: :transient, else: false),
        max_retries: max_attempts - 1,
        retry_delay: fn n -> SatOps.Backoff.delay(n + 1, base_ms: 200, max_ms: 5_000) end,
        retry_log_level: false
      )
      |> case do
        {:ok, %{status: status} = resp} when status in 200..299 -> {:ok, resp}
        {:ok, %{status: status}} -> {:error, {:http_status, status}}
        {:error, %{reason: :timeout}} -> {:error, :timeout}
        {:error, %Req.TransportError{reason: reason}} -> {:error, {:transport, reason}}
        {:error, other} -> {:error, {:transport, other}}
      end
    end
  end
end
