defmodule SatOps.Events.Consumer do
  @callback name() :: String.t()
  @callback interested?(event_type :: String.t()) :: boolean()
  @callback handle(SatOps.Events.Event.t()) :: :ok | {:error, term()}
end
