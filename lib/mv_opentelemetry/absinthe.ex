defmodule MvOpentelemetry.Absinthe do
  @moduledoc false

  require OpenTelemetry.Tracer
  alias OpenTelemetry.Span

  @tracer_id __MODULE__
  @tracer_version "0.1.0"

  def register_tracer(opts) do
    opts = handle_opts(opts)
    prefix = opts[:span_prefix]
    tracer_id = opts[:tracer_id]
    tracer_version = opts[:tracer_version]
    :opentelemetry.register_tracer(tracer_id, tracer_version)

    :ok =
      :telemetry.attach_many(
        {tracer_id, __MODULE__, :handle_start_event},
        Enum.map(prefix, fn x -> x ++ [:start] end),
        &__MODULE__.handle_start_event/4,
        opts
      )

    :ok =
      :telemetry.attach_many(
        {tracer_id, __MODULE__, :handle_stop_event},
        Enum.map(prefix, fn x -> x ++ [:stop] end),
        &__MODULE__.handle_stop_event/4,
        opts
      )
  end

  defp handle_opts(opts) do
    span_prefix =
      opts[:span_prefix] || [[:absinthe, :execute, :operation], [:absinthe, :resolve, :field]]

    name_prefix = opts[:name_prefix] || span_prefix
    tracer_id = opts[:tracer_id] || @tracer_id
    tracer_version = opts[:tracer_version] || @tracer_version

    [
      span_prefix: span_prefix,
      name_prefix: name_prefix,
      tracer_id: tracer_id,
      tracer_version: tracer_version
    ]
  end

  def handle_start_event([:absinthe, :resolve, :field, :start], _measurements, meta, _opts) do
    event_name = Enum.join([:absinthe, :resolve, :field], ".")

    resolution = meta.resolution

    attributes = [
      "graphql.field.arguments": resolution.arguments,
      "graphql.field.name": resolution.definition.name,
      "graphql.field.schema": resolution.schema
    ]

    OpentelemetryTelemetry.start_telemetry_span(@tracer_id, event_name, meta, %{})
    |> Span.set_attributes(attributes)
  end

  def handle_start_event([:absinthe, :execute, :operation, :start], _measurements, meta, _opts) do
    event_name = Enum.join([:absinthe, :execute, :operation], ".")

    attributes = [
      "graphql.operation.input": meta.blueprint.input
    ]

    OpentelemetryTelemetry.start_telemetry_span(@tracer_id, event_name, meta, %{})
    |> Span.set_attributes(attributes)

    :ok
  end

  def handle_stop_event([:absinthe, :resolve, :field, :stop], _measurements, meta, _opts) do
    resolution = meta.resolution
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, meta)

    attributes = [
      "graphql.field.state": resolution.state,
      "graphql.field.value": Jason.encode!(resolution.value)
    ]

    Span.set_attributes(ctx, attributes)
    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, meta)
    :ok
  end

  def handle_stop_event([:absinthe, :execute, :operation, :stop], _measurements, meta, _opts) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, meta)

    attributes = [
      "graphql.operation.schema": meta.blueprint.schema,
      "graphql.operation.result": Jason.encode!(meta.blueprint.result)
    ]

    Span.set_attributes(ctx, attributes)
    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, meta)
    :ok
  end
end
