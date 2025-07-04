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
    :ok = MvOpentelemetry.register_tracer(:broadway)
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
  @type traced_apps ::
          :absinthe
          | :bandit
          | :broadway
          | :cowboy
          | :dataloader
          | :ecto
          | :finch
          | :live_view
          | :plug
          | :oban
          | :tesla

  @spec register_tracer(traced_apps()) :: :ok
  def register_tracer(atom), do: register_tracer(atom, [])

  @doc """
  Registers tracer for given functional area with options.
  Allowed areas are: :absinthe, :cowboy, :broadway, :dataloader, :ecto, :live_view, :oban and :plug.
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
      traces, i.e ["user_id", "product_id"]. Defaults to logging none at all.

  ## Absinthe
    - `prefix` OPTIONAL telemetry prefix that will be emited in events, defaults to "graphql"
    - `default_attributes` OPTIONAL property list of attributes you want to attach to all traces
      from this group, for example [{"service.component", "ecto"}]. Defaults to []
    - `include_field_resolution` OPTIONAL boolean for subscribing to field resolution events.
      These tend to be noisy and produce a lot of spans, so the default is set to `false`

  ## Dataloader
    - `default_attributes` OPTIONAL property list of attributes you want to attach to all traces
      from this group, for example [{"service.component", "ecto"}]. Defaults to []

  ## Cowboy
  This is a shallow wrapper for opentelemetry_cowboy. It accepts the same options as
  opentelemetry_cowboy:setup/1 with the following extra defaults:
  - public_endpoint: false
  - request_headers: ["referer"]
  - response_headers: ["x-request-id"]

  ## Bandit
  This is a shallow wrapper for opentelemetry_bandit. It accepts the same options as
  OpentelemetryBandit.setup/1 with the following extra defaults:
  - public_endpoint: false
  - request_headers: ["referer"]
  - response_headers: ["x-request-id"]

  ## Plug
  NB! Requires cowboy tracer being set up! Then accepts the following options:

    - `adapter` REQUIRED argument to identify which server you are running. Currently only supports
      `cowboy`, which is also the default one.
    - `span_prefix` OPTIONAL telemetry prefix to listen to. Defaults to [:phoenix, :endpoint]

  ## Broadway
    - `default_attributes` OPTIONAL property list of attributes you want to attach to all traces
      from this group, for example [{"service.component", "my_app"}]. Defaults to []

  ## Oban
    - `default_attributes` OPTIONAL property list of attributes you want to attach to all traces
    from this group, for example [{"service.component", "my_app"}]. Defaults to []

  ## Finch
    - `default_attributes` OPTIONAL property list of attributes you want to attach to all traces
      from this group, for example [{"service.component", "my_app"}]. Defaults to []

  ## Tesla
    - `default_attributes` OPTIONAL property list of attributes you want to attach to all traces
      from this group, for example [{"service.component", "my_app"}]. Defaults to []
  """

  @spec register_tracer(traced_apps(), Access.t()) :: :ok
  def register_tracer(:absinthe, opts), do: __MODULE__.Absinthe.register_tracer(opts)
  def register_tracer(:bandit, opts), do: __MODULE__.Bandit.register_tracer(opts)
  def register_tracer(:broadway, opts), do: __MODULE__.Broadway.Messages.register_tracer(opts)
  def register_tracer(:cowboy, opts), do: __MODULE__.Cowboy.register_tracer(opts)
  def register_tracer(:dataloader, opts), do: __MODULE__.Dataloader.register_tracer(opts)
  def register_tracer(:ecto, opts), do: __MODULE__.Ecto.register_tracer(opts)
  def register_tracer(:finch, opts), do: __MODULE__.Finch.register_tracer(opts)
  def register_tracer(:live_view, opts), do: __MODULE__.LiveView.register_tracer(opts)
  def register_tracer(:oban, opts), do: __MODULE__.Oban.register_tracer(opts)
  def register_tracer(:plug, opts), do: __MODULE__.Plug.register_tracer(opts)
  def register_tracer(:tesla, opts), do: __MODULE__.Tesla.register_tracer(opts)

  def version, do: "3.3.0"
end
