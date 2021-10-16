defmodule MvOpentelemetry do
  @moduledoc """
  Top level module for Opentelemetry instrumentation, as used at Mindvalley.
  Used to publish Opentelemetry events to applicable processors, for example
  to Honeycomb.

  Opentelemetry resources and processor are configured outside of the scope
  of this module, use Opentelemetry directly.

  # Example usage
  ```
  # Somewhere in your application startup, for example in Application.start/2:

  def start(_type, _args) do
    :ok = MvOpentelemetry.register_tracer(:ecto, span_prefix: [:my_app, :repo])

    :ok =
      MvOpentelemetry.register_tracer(:ecto,
        span_prefix: [:my_app, :replica_repo],
        tracer_id: :replica
      )

    :ok = MvOpentelemetry.register_tracer(:plug)
    :ok = MvOpentelemetry.register_tracer(:live_view)
  end

  ## Note about Absinthe tracers

  In case your application uses Absinthe to implement GraphQL and you return structs from your
  resolvers, ensure that each of the structs implements the MvOpentelemetry.Sanitizer protocol.
  ```
  """

  @doc """
  Convert a data structure into another one, that is safe to store in a tracing backend
  and can be converted to JSON.

  You can use this function to implement your own tracers. It is also used to sanitize
  absinthe data.
  """
  @spec sanitize(MvOpentelemetry.Sanitizer.t()) :: {:error, Exception.t()} | term()
  def sanitize(value), do: MvOpentelemetry.Sanitize.sanitize!(value)

  @doc """
  Same as sanitize/1, but raises on error.
  """
  @spec sanitize!(MvOpentelemetry.Sanitizer.t()) :: term()
  def sanitize!(value), do: MvOpentelemetry.Sanitize.sanitize!(value)

  defmodule Error do
    defexception [:message, :module]
  end

  @doc """
  Registers tracer for given functional area. Allowed areas are: :ecto, :plug, :absinthe
  and :live_view
  """
  @spec register_tracer(:ecto | :plug | :live_view | :absinthe) :: :ok
  def register_tracer(atom), do: register_tracer(atom, [])

  @doc false
  def version, do: "1.0.0-rc.3"

  @doc """
  Registers tracer for given functional area with options.
  Allowed areas are: :ecto, :phoenix and :live_view.
  You can also provide following options:

  ## Ecto
    - `span_prefix` REQUIRED telemetry prefix to listen to. If you're unsure of what to put here,
    [:my_app, :repo] is the right choice.
    - `name_prefix` OPTIONAL telemetry prefix that will be emited in events, for example
    [:my_app, :ecto]
    - `tracer_id` OPTIONAL atom to identify tracers in case you want to listen to events from
    different repositories.

  ## LiveView
    - `prefix` OPTIONAL telemetry prefix that will be emited in events, for example
    "my_app.phoenix". Defaults to "phoenix"
    - `name` OPTIONAL atom to identify tracers in case you want to listen to events from
    live_view twice.

  ## Absinthe
    - `prefix` OPTIONAL telemetry prefix that will be emited in events, defaults to "absinthe"

  ## Plug
    - `span_prefix` OPTIONAL telemetry prefix to listen to. Defaults to [:phoenix, :endpoint]
    - `name_prefix` OPTIONAL telemetry prefix that will be emited in events, for example
    [:my_app, :live_view]. Defaults to span_prefix.
    - `tracer_id` OPTIONAL atom to identify tracers in case you want to listen to events from
    Plug.Telemetry twice.
  """
  @spec register_tracer(:absinthe | :ecto | :plug | :live_view, Access.t()) :: :ok
  def register_tracer(:absinthe, opts), do: MvOpentelemetry.Absinthe.register_tracer(opts)
  def register_tracer(:ecto, opts), do: MvOpentelemetry.Ecto.register_tracer(opts)
  def register_tracer(:plug, opts), do: MvOpentelemetry.Plug.register_tracer(opts)
  def register_tracer(:live_view, opts), do: MvOpentelemetry.LiveView.register_tracer(opts)
end
