defmodule MvOpentelemetry.LiveView do
  @moduledoc false

  alias OpenTelemetry.Span

  @tracer_id __MODULE__

  @live_view_events [
    [:phoenix, :live_view, :mount, :start],
    [:phoenix, :live_view, :mount, :stop],
    [:phoenix, :live_view, :mount, :exception],
    [:phoenix, :live_view, :handle_params, :start],
    [:phoenix, :live_view, :handle_params, :stop],
    [:phoenix, :live_view, :handle_params, :exception],
    [:phoenix, :live_view, :handle_event, :start],
    [:phoenix, :live_view, :handle_event, :stop],
    [:phoenix, :live_view, :handle_event, :exception],
    [:phoenix, :live_component, :handle_event, :start],
    [:phoenix, :live_component, :handle_event, :stop],
    [:phoenix, :live_component, :handle_event, :exception]
  ]

  def register_tracer(opts) do
    opts = handle_opts(opts)
    name_prefix = opts[:name_prefix]
    tracer_id = opts[:tracer_id]
    tracer_version = opts[:tracer_version]

    :opentelemetry.register_tracer(tracer_id, tracer_version)

    :telemetry.attach_many(
      {tracer_id, __MODULE__, :handle_event},
      @live_view_events,
      &__MODULE__.handle_event/4,
      name_prefix: name_prefix
    )

    :ok
  end

  defp handle_opts(opts) do
    name_prefix = Access.get(opts, :name_prefix, [:phoenix])
    tracer_id = opts[:tracer_id] || @tracer_id
    tracer_version = opts[:tracer_version] || MvOpentelemetry.version()

    [
      name_prefix: name_prefix,
      tracer_id: tracer_id,
      tracer_version: tracer_version
    ]
  end

  defp get_name([:phoenix, component, action, _], config) do
    list = config[:name_prefix] ++ [component, action]
    Enum.join(list, ".")
  end

  def handle_event([:phoenix, :live_view, :mount, :start] = event, _measurements, meta, config) do
    attributes = [
      "live_view.view": meta.socket.view,
      "live_view.params": meta.params
    ]

    name = get_name(event, config)

    OpentelemetryTelemetry.start_telemetry_span(@tracer_id, name, meta, %{})
    |> Span.set_attributes(attributes)

    :ok
  end

  def handle_event(
        [:phoenix, :live_view, :handle_params, :start] = event,
        _measurements,
        meta,
        config
      ) do
    attributes = [
      "live_view.view": meta.socket.view,
      "live_view.params": meta.params,
      "live_view.uri": meta.uri
    ]

    name = get_name(event, config)

    OpentelemetryTelemetry.start_telemetry_span(@tracer_id, name, meta, %{})
    |> Span.set_attributes(attributes)

    :ok
  end

  def handle_event(
        [:phoenix, :live_view, :handle_event, :start] = event,
        _measurements,
        meta,
        config
      ) do
    attributes = [
      "live_view.view": meta.socket.view,
      "live_view.params": meta.params,
      "live_view.uri": meta.uri,
      "live_view.event": meta.event
    ]

    name = get_name(event, config)

    OpentelemetryTelemetry.start_telemetry_span(@tracer_id, name, meta, %{})
    |> Span.set_attributes(attributes)

    :ok
  end

  def handle_event(
        [:phoenix, :live_component, :handle_event, :start] = event,
        _measurements,
        meta,
        config
      ) do
    attributes = [
      "live_component.view": meta.socket.view,
      "live_component.event": meta.event,
      "live_component.component": meta.component,
      "live_component.host_uri": meta.socket.host_uri,
      "live_component.uri": meta.uri
    ]

    name = get_name(event, config)

    OpentelemetryTelemetry.start_telemetry_span(@tracer_id, name, meta, %{})
    |> Span.set_attributes(attributes)

    :ok
  end

  def handle_event([:phoenix, :live_view, _, :exception], _measurements, meta, _config) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, meta)
    Span.set_status(ctx, OpenTelemetry.status(:error, ""))

    attributes = [
      "live_view.kind": meta.kind,
      "live_view.reason": meta.reason,
      error: true
    ]

    Span.set_attributes(ctx, attributes)
    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, meta)
    :ok
  end

  def handle_event([:phoenix, :live_component, _, :exception], _measurements, meta, _config) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, meta)
    Span.set_status(ctx, OpenTelemetry.status(:error, ""))

    attributes = [
      "live_component.kind": meta.kind,
      "live_component.reason": meta.reason,
      error: true
    ]

    Span.set_attributes(ctx, attributes)
    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, meta)
    :ok
  end

  def handle_event([:phoenix, _, _, :stop], _measurements, meta, _config) do
    _ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, meta)
    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, meta)
    :ok
  end
end
