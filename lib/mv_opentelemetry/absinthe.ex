defmodule MvOpentelemetry.Absinthe do
  @moduledoc false

  use MvOpentelemetry.SpanTracer,
    name: :absinthe,
    events: [
      [:absinthe, :execute, :operation, :start],
      [:absinthe, :execute, :operation, :stop],
      [:absinthe, :execute, :operation, :exception],
      [:absinthe, :resolve, :field, :start],
      [:absinthe, :resolve, :field, :stop],
      [:absinthe, :resolve, :field, :exception]
    ]

  def handle_event([:absinthe, :resolve, :field, :start], _measurements, meta, opts) do
    event_name = [opts[:prefix]] ++ [:resolve, :field]

    resolution = meta.resolution

    event_name =
      case resolution.definition.name do
        x when is_bitstring(x) ->
          Enum.join(event_name ++ [x], ".")

        _ ->
          Enum.join(event_name, ".")
      end

    resolution = meta.resolution

    attributes = [
      "graphql.field.name": resolution.definition.name,
      "graphql.field.schema": resolution.schema
    ]

    OpentelemetryTelemetry.start_telemetry_span(opts[:tracer_id], event_name, meta, %{})
    |> Span.set_attributes(attributes)

    :ok
  end

  def handle_event([:absinthe, :execute, :operation, :start], _measurements, meta, opts) do
    event_name = Enum.join([opts[:prefix]] ++ [:execute, :operation], ".")

    attributes = [
      "graphql.operation.input": meta.blueprint.input
    ]

    OpentelemetryTelemetry.start_telemetry_span(opts[:tracer_id], event_name, meta, %{})
    |> Span.set_attributes(attributes)

    :ok
  end

  def handle_event([:absinthe, :resolve, :field, :stop], _measurements, meta, opts) do
    resolution = meta.resolution
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)

    attributes = ["graphql.field.state": resolution.state]

    Span.set_attributes(ctx, attributes)
    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
    :ok
  end

  def handle_event([:absinthe, :execute, :operation, :stop], _measurements, meta, opts) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)
    attributes = ["graphql.operation.schema": meta.blueprint.schema]

    Span.set_attributes(ctx, attributes)
    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
    :ok
  end
end
