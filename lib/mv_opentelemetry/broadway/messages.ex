defmodule MvOpentelemetry.Broadway.Messages do
  @moduledoc false

  use MvOpentelemetry.SpanTracer,
    name: :broadway,
    events: [
      [:broadway, :processor, :start],
      [:broadway, :processor, :stop],
      [:broadway, :processor, :message, :start],
      [:broadway, :processor, :message, :stop],
      [:broadway, :processor, :message, :exception]
    ]

  @spec handle_event([atom()], map(), map(), Access.t()) :: :ok
  def handle_event([:broadway, :processor, :start], _measurements, meta, opts) do
    attributes = [
      {"broadway.topology_name", meta.topology_name |> inspect()},
      {"broadway.stage", :processor},
      {"broadway.index", meta.index},
      {"broadway.processor_key", meta.processor_key},
      {"broadway.messages_count", length(meta.messages)}
    ]

    event_name = "broadway.processor.start"
    attributes = attributes ++ opts[:default_attributes]

    OpentelemetryTelemetry.start_telemetry_span(__MODULE__, event_name, meta, %{
      attributes: attributes
    })

    :ok
  end

  def handle_event([:broadway, :processor, :stop], _measurements, metadata, opts) do
    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], metadata)
  end

  def handle_event([:broadway, :processor, :message, :start], _measurements, meta, opts) do
    span_name = "broadway.processor.message.start"

    attributes = %{}

    OpentelemetryTelemetry.start_telemetry_span(opts[:tracer_id], span_name, meta, %{
      attributes: attributes
    })
  end

  def handle_event([:broadway, :processor, :message, :stop], _measurements, meta, opts) do
    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
  end

  def handle_event([:broadway, :processor, :message, :exception], _measurements, meta, opts) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)

    OpenTelemetry.Span.record_exception(ctx, meta.reason, meta.stacktrace)
    OpenTelemetry.Tracer.set_status(OpenTelemetry.status(:error, format_error(meta.reason)))

    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
  end

  defp format_error(exception) when is_exception(exception), do: Exception.message(exception)
  defp format_error(error), do: inspect(error)
end
