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
    :ok = MvOpentelemetry.register_tracer(:ecto, span_prefix: [:my_app, :replica_repo])
    :ok = MvOpentelemetry.register_tracer(:plug)
    :ok = MvOpentelemetry.register_tracer(:live_view)
  end

  ```
  """

  defmodule Error do
    defexception [:message, :module]
  end

  @doc """
  Registers tracer for given functional area. Allowed areas are: :ecto, :plug, :absinthe,
  :dataloader and :live_view
  """
  @spec register_tracer(:ecto | :plug | :live_view | :absinthe | :dataloader) :: :ok
  def register_tracer(atom), do: register_tracer(atom, [])

  @doc false
  def version, do: "1.1.0"

  @doc """
  Registers tracer for given functional area with options.
  Allowed areas are: :absinthe, :dataloader, :ecto, :phoenix and :live_view.
  You can also provide following options:

  ## Ecto
    - `span_prefix` REQUIRED telemetry prefix to listen to. If you're unsure of what to put here,
    [:my_app, :repo] is the right choice.
    - `default_attributes` OPTIONAL property list of attributes you want to attach to all traces
      from this group, for example [{"service.component", "my_app"}]. Defaults to []

  ## LiveView
    - `prefix` OPTIONAL telemetry prefix that will be emited in events, for example
    "my_app.phoenix". Defaults to "phoenix"
    - `name` OPTIONAL atom to identify tracers in case you want to listen to events from
    live_view twice.
    - `default_attributes` OPTIONAL property list of attributes you want to attach to all traces
      from this group, for example [{"service.component", "my_app"}]. Defaults to []
    - `query_params_whitelist` OPTIONAL list of query param names you want to allow to log in your
      traces, i.e ["user_id", "product_id"]. Defaults to logging all.

  ## Absinthe
    - `prefix` OPTIONAL telemetry prefix that will be emited in events, defaults to "graphql"
    - `default_attributes` OPTIONAL property list of attributes you want to attach to all traces
      from this group, for example [{"service.component", "ecto"}]. Defaults to []

  ## Dataloader
    - `default_attributes` OPTIONAL property list of attributes you want to attach to all traces
      from this group, for example [{"service.component", "ecto"}]. Defaults to []

  ## Plug
    - `span_prefix` OPTIONAL telemetry prefix to listen to. Defaults to [:phoenix, :endpoint]
    - `default_attributes` OPTIONAL property list of attributes you want to attach to all traces
      from this group, for example [{"service.component", "ecto"}]. Defaults to []
    - `query_params_whitelist` OPTIONAL list of query param names you want to allow to log in your
      traces, i.e ["user_id", "product_id"]. Defaults to logging all.

  """
  @spec register_tracer(:absinthe | :dataloader | :ecto | :plug | :live_view, Access.t()) :: :ok
  def register_tracer(:absinthe, opts), do: MvOpentelemetry.Absinthe.register_tracer(opts)
  def register_tracer(:dataloader, opts), do: MvOpentelemetry.Dataloader.register_tracer(opts)
  def register_tracer(:ecto, opts), do: MvOpentelemetry.Ecto.register_tracer(opts)
  def register_tracer(:plug, opts), do: MvOpentelemetry.Plug.register_tracer(opts)
  def register_tracer(:live_view, opts), do: MvOpentelemetry.LiveView.register_tracer(opts)
end
