defmodule SatOpsWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :sat_ops

  socket "/socket", SatOpsWeb.UserSocket,
    websocket: [connect_info: [:peer_data, cookies: ["satops_session"]], check_origin: false],
    longpoll: false

  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug SatOpsWeb.Plugs.RawBody

  plug Plug.Parsers,
    parsers: [:json, :multipart],
    pass: ["application/json", "multipart/form-data", "text/csv"],
    json_decoder: Phoenix.json_library(),
    length: 2_000_000,
    body_reader: {SatOpsWeb.Plugs.RawBody, :read_body, []}

  plug Plug.Head
  plug SatOpsWeb.Plugs.SecurityHeaders
  plug SatOpsWeb.Router
end
