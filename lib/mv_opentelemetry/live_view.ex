defmodule MvOpentelemetry.LiveView do
  use MvOpentelemetry.SpanTracer,
    name: :live_view,
    prefix: :phoenix,
    events: [
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

  defp get_name([:phoenix, component, action, _], opts) do
    list = [opts[:prefix]] ++ [component, action]
    Enum.join(list, ".")
  end

  def handle_event([:phoenix, :live_view, :mount, :start] = event, _measurements, meta, opts) do
    attributes = [
      "live_view.view": meta.socket.view,
      "live_view.params": meta.params
    ]

    name = get_name(event, opts)

    OpentelemetryTelemetry.start_telemetry_span(opts[:tracer_id], name, meta, %{})
    |> Span.set_attributes(attributes)

    :ok
  end

  def handle_event(
        [:phoenix, :live_view, :handle_params, :start] = event,
        _measurements,
        meta,
        opts
      ) do
    attributes = [
      "live_view.view": meta.socket.view,
      "live_view.params": meta.params,
      "live_view.uri": meta.uri
    ]

    name = get_name(event, opts)

    OpentelemetryTelemetry.start_telemetry_span(opts[:tracer_id], name, meta, %{})
    |> Span.set_attributes(attributes)

    :ok
  end

  def handle_event(
        [:phoenix, :live_view, :handle_event, :start] = event,
        _measurements,
        meta,
        opts
      ) do
    attributes = [
      "live_view.view": meta.socket.view,
      "live_view.params": meta.params,
      "live_view.uri": meta.uri,
      "live_view.event": meta.event
    ]

    name = get_name(event, opts)

    OpentelemetryTelemetry.start_telemetry_span(opts[:tracer_id], name, meta, %{})
    |> Span.set_attributes(attributes)

    :ok
  end

  def handle_event(
        [:phoenix, :live_component, :handle_event, :start] = event,
        _measurements,
        meta,
        opts
      ) do
    attributes = [
      "live_component.view": meta.socket.view,
      "live_component.event": meta.event,
      "live_component.component": meta.component,
      "live_component.host_uri": meta.socket.host_uri,
      "live_component.uri": meta.uri
    ]

    name = get_name(event, opts)

    OpentelemetryTelemetry.start_telemetry_span(opts[:tracer_id], name, meta, %{})
    |> Span.set_attributes(attributes)

    :ok
  end

  def handle_event([:phoenix, :live_view, _, :exception], _measurements, meta, opts) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)
    Span.set_status(ctx, OpenTelemetry.status(:error, ""))

    attributes = [
      "live_view.kind": meta.kind,
      "live_view.reason": meta.reason,
      error: true
    ]

    Span.set_attributes(ctx, attributes)
    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
    :ok
  end

  def handle_event([:phoenix, :live_component, _, :exception], _measurements, meta, opts) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)
    Span.set_status(ctx, OpenTelemetry.status(:error, ""))

    attributes = [
      "live_component.kind": meta.kind,
      "live_component.reason": meta.reason,
      error: true
    ]

    Span.set_attributes(ctx, attributes)
    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
    :ok
  end

  def handle_event([:phoenix, _, _, :stop], _measurements, meta, opts) do
    _ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)
    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
    :ok
  end
end
