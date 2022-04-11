defmodule MvOpentelemetry.Dataloader do
  @moduledoc false

  require OpenTelemetry.Tracer, as: Tracer

  use MvOpentelemetry.SpanTracer,
    events: [
      [:dataloader, :source, :run, :start],
      [:dataloader, :source, :run, :stop],
      [:dataloader, :source, :batch, :run, :stop]
    ]

  @spec handle_event([atom()], map(), map(), Access.t()) :: :ok
  def handle_event([:dataloader, :source, :run, :start], _measurements, meta, opts) do
    event_name = "dataloader.source.run"

    parent_context = OpentelemetryProcessPropagator.fetch_parent_ctx(1, :"$callers")
    attach_context(parent_context)

    OpentelemetryTelemetry.start_telemetry_span(__MODULE__, event_name, meta, %{})
    |> Span.set_attributes(opts[:default_attributes])

    :ok
  end

  def handle_event([:dataloader, :source, :run, :stop], _measurements, meta, _opts) do
    OpentelemetryTelemetry.end_telemetry_span(__MODULE__, meta)
    :ok
  end

  def handle_event(
        [:dataloader, :source, :batch, :run, :stop],
        measurements,
        %{batch: batch},
        opts
      ) do
    event_name = "dataloader.source.batch.run"

    batch_attributes =
      case batch do
        {{:queryable, _pid, queryable, cardinality, col, _}, _} ->
          [
            {"dataloader.source.batch.type", "queryable"},
            {"dataloader.source.batch.queryable", queryable},
            {"dataloader.source.batch.cardinality", cardinality},
            {"dataloader.source.batch.column", col}
          ]

        {{:assoc, schema, _pid, assoc_field, queryable, _}, _} ->
          [
            {"dataloader.source.batch.type", "assoc"},
            {"dataloader.source.batch.schema", schema},
            {"dataloader.source.batch.assoc_field", assoc_field},
            {"dataloader.source.batch.queryable", queryable}
          ]

        _ ->
          []
      end

    %{duration: duration} = measurements
    end_time = :opentelemetry.timestamp()
    start_time = end_time - duration
    attributes = batch_attributes ++ opts[:default_attributes]
    span_opts = %{start_time: start_time, attributes: attributes}

    parent_context = OpentelemetryProcessPropagator.fetch_parent_ctx(4, :"$callers")
    attach_context(parent_context)

    span = Tracer.start_span(event_name, span_opts)
    Span.end_span(span)
    detach_context(parent_context)

    :ok
  end

  defp attach_context(:undefined), do: :ok
  defp attach_context(context), do: OpenTelemetry.Ctx.attach(context)

  defp detach_context(:undefined), do: :ok
  defp detach_context(context), do: OpenTelemetry.Ctx.detach(context)
end
