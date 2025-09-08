defmodule MvOpentelemetry.Plug do
  @moduledoc false

  alias OpenTelemetry.SemConv

  require OpenTelemetry.Tracer, as: Tracer

  @spec register_tracer(opts :: Access.t()) :: :ok
  def register_tracer(opts) do
    opts = handle_opts(opts)
    prefix = opts[:span_prefix]

    :ok =
      :telemetry.attach(
        {prefix, __MODULE__, :handle_start_event},
        prefix ++ [:start],
        &__MODULE__.handle_start_event/4,
        opts
      )

    :ok =
      :telemetry.attach(
        {prefix, __MODULE__, :handle_router_event},
        [:phoenix, :router_dispatch, :start],
        &__MODULE__.handle_router_dispatch/4,
        opts
      )
  end

  defp handle_opts(opts) do
    span_prefix = opts[:span_prefix] || [:phoenix, :endpoint]
    tracer_id = :mv_opentelemetry
    adapter = opts[:adapter] || :cowboy

    %{span_prefix: span_prefix, tracer_id: tracer_id, adapter: adapter}
  end

  @spec handle_start_event(_event :: any(), _measurements :: any(), _meta :: any(), Access.t()) ::
          :ok
  def handle_start_event(_event, _mesurements, _meta, opts) do
    case opts[:adapter] do
      :cowboy ->
        OpentelemetryProcessPropagator.fetch_parent_ctx()
        |> OpenTelemetry.Ctx.attach()

        :ok

      :bandit ->
        :ok
    end
  end

  @spec handle_router_dispatch(
          _event :: any(),
          _measurements :: any(),
          meta :: %{conn: %{method: any()}, plug: atom(), plug_opts: atom(), route: atom()},
          Access.t()
        ) ::
          :ok
  def handle_router_dispatch(_event, _measurements, meta, opts) do
    case opts[:adapter] do
      :cowboy ->
        OpentelemetryProcessPropagator.fetch_parent_ctx()
        |> OpenTelemetry.Ctx.attach()

        :ok

      :bandit ->
        :ok
    end

    attributes =
      %{
        :"phoenix.plug" => meta.plug,
        :"phoenix.action" => meta.plug_opts,
        SemConv.HTTPAttributes.http_route() => meta.route
      }
      |> maybe_put_force_trace(meta)

    Tracer.update_name("#{meta.conn.method} #{meta.route}")
    Tracer.set_attributes(attributes)

    :ok
  end

  defp maybe_put_force_trace(attributes, meta) do
    case :proplists.get_value("x-force-sample", meta.conn.req_headers) do
      "true" -> Map.put(attributes, :force_sample, true)
      _ -> attributes
    end
  end
end
