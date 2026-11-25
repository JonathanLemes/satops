defmodule SatOps.Infrastructure.Bitcoin.RPC do
  defstruct [:url, :user, :password, timeout: 5_000, wallet: nil]

  @type t :: %__MODULE__{}

  def new(opts) do
    struct!(__MODULE__, opts)
  end

  def with_wallet(%__MODULE__{} = rpc, wallet), do: %{rpc | wallet: wallet}

  def call(%__MODULE__{} = rpc, method, params \\ []) do
    started = System.monotonic_time()
    url = if rpc.wallet, do: rpc.url <> "/wallet/" <> URI.encode(rpc.wallet), else: rpc.url

    result =
      Req.post(url,
        json: %{jsonrpc: "1.0", id: "satops", method: method, params: params},
        auth: {:basic, "#{rpc.user}:#{rpc.password}"},
        receive_timeout: rpc.timeout,
        connect_options: [timeout: min(rpc.timeout, 3_000)],
        retry: false,
        redirect: false,
        decode_json: [floats: :decimals]
      )

    duration = System.monotonic_time() - started

    :telemetry.execute([:sat_ops, :bitcoin, :rpc], %{duration: duration}, %{
      method: method,
      ok: match?({:ok, %{status: 200}}, result)
    })

    interpret(result)
  end

  defp interpret({:ok, %{status: status, body: %{"error" => nil, "result" => result}}}) when status in 200..299,
    do: {:ok, result}

  defp interpret({:ok, %{body: %{"error" => %{"code" => code, "message" => message}}}}),
    do: {:error, {:rpc, code, message}}

  defp interpret({:ok, %{status: 401}}), do: {:error, :unauthorized}
  defp interpret({:ok, %{status: status}}), do: {:error, {:http, status}}
  defp interpret({:error, %{reason: :timeout}}), do: {:error, :timeout}
  defp interpret({:error, %Req.TransportError{reason: reason}}), do: {:error, {:transport, reason}}
  defp interpret({:error, error}), do: {:error, {:transport, error}}

  def latency_call(rpc, method, params \\ []) do
    started = System.monotonic_time(:millisecond)
    result = call(rpc, method, params)
    {result, System.monotonic_time(:millisecond) - started}
  end

  def btc_to_sats(%Decimal{} = btc), do: btc |> Decimal.mult(100_000_000) |> Decimal.round(0) |> Decimal.to_integer()
  def btc_to_sats(btc) when is_integer(btc), do: btc * 100_000_000

  def sats_to_btc(sats) when is_integer(sats), do: Decimal.div(Decimal.new(sats), 100_000_000) |> Decimal.round(8)
end
