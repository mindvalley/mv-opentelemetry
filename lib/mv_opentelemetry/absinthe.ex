defmodule MvOpentelemetry.Absinthe do
  @moduledoc false

  use MvOpentelemetry.SpanTracer,
    name: :graphql,
    events: [
      [:absinthe, :execute, :operation, :start],
      [:absinthe, :execute, :operation, :stop],
      [:absinthe, :execute, :operation, :exception],
      [:absinthe, :resolve, :field, :start],
      [:absinthe, :resolve, :field, :stop],
      [:absinthe, :resolve, :field, :exception]
    ]

  @field_resolution_events [
    [:absinthe, :resolve, :field, :start],
    [:absinthe, :resolve, :field, :stop],
    [:absinthe, :resolve, :field, :exception]
  ]

  def register_tracer(opts) do
    module_opts = __opts__()
    prefix = Access.get(opts, :prefix, module_opts[:name])
    name = Access.get(opts, :name, module_opts[:name])
    tracer_id = :mv_opentelemetry

    default_attributes = Access.get(opts, :default_attributes, [])
    include_field_resolution = Access.get(opts, :include_field_resolution, false)

    opts_with_defaults =
      merge_defaults(opts,
        prefix: prefix,
        name: name,
        tracer_id: tracer_id,
        default_attributes: default_attributes
      )
      |> merge_default(:include_field_resolution, include_field_resolution)

    events =
      if include_field_resolution do
        module_opts[:events]
      else
        module_opts[:events] -- @field_resolution_events
      end

    :telemetry.attach_many(
      {name, __MODULE__},
      events,
      &__MODULE__.handle_event/4,
      opts_with_defaults
    )
  end

  @spec handle_event([atom()], map(), map(), Access.t()) :: :ok
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
      {"graphql.field.name", resolution.definition.name},
      {"graphql.field.schema", resolution.schema}
    ]

    attributes = attributes ++ opts[:default_attributes]

    OpentelemetryTelemetry.start_telemetry_span(opts[:tracer_id], event_name, meta, %{})
    |> Span.set_attributes(attributes)

    :ok
  end

  def handle_event([:absinthe, :execute, :operation, :start], _measurements, meta, opts) do
    event_name = Enum.join([opts[:prefix]] ++ [:execute, :operation], ".")

    attributes = [{"graphql.operation.input", meta.blueprint.input}] ++ opts[:default_attributes]

    OpentelemetryTelemetry.start_telemetry_span(opts[:tracer_id], event_name, meta, %{})
    |> Span.set_attributes(attributes)

    :ok
  end

  def handle_event([:absinthe, :resolve, :field, :stop], _measurements, meta, opts) do
    resolution = meta.resolution
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)

    attributes = [{"graphql.field.state", resolution.state}]

    Span.set_attributes(ctx, attributes)
    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
    :ok
  end

  def handle_event([:absinthe, :execute, :operation, :stop], _measurements, meta, opts) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)
    attributes = [{"graphql.operation.schema", meta.blueprint.schema}]

    Span.set_attributes(ctx, attributes)
    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
    :ok
  end
end
