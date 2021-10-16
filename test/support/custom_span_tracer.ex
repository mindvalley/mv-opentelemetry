defmodule MvOpentelemetry.CustomSpanTracer do
  @moduledoc false

  use MvOpentelemetry.SpanTracer,
    events: [
      [:my_event, :do_stuff, :start],
      [:my_event, :do_stuff, :stop],
      [:my_event, :do_stuff, :exception]
    ]

  def handle_event([:my_event, :do_stuff, :start], _measurements, meta, opts) do
    event_name = "my_event.do_stuff"
    attributes = ["my_event.name": meta.name]

    OpentelemetryTelemetry.start_telemetry_span(opts[:name], event_name, meta, %{})
    |> Span.set_attributes(attributes)

    :ok
  end

  def handle_event([:my_event, :do_stuff, :stop], _measurements, meta, opts) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:name], meta)
    attributes = ["my_event.result": meta.result]

    Span.set_attributes(ctx, attributes)
    OpentelemetryTelemetry.end_telemetry_span(opts[:name], meta)

    :ok
  end

  def handle_event([:my_event, :do_stuff, :exception], _measurements, meta, opts) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:name], meta)

    attributes = [reason: meta.reason, error: true, stacktrace: meta.stacktrace, kind: meta.kind]

    Span.set_attributes(ctx, attributes)
    OpentelemetryTelemetry.end_telemetry_span(opts[:name], meta)

    :ok
  end

  def raise_test_error do
    :telemetry.span([:my_event, :do_stuff], %{name: "custom"}, fn ->
      raise "boo!"
    end)
  end
end
