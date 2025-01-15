defmodule MvOpentelemetry.Oban do
  @moduledoc false

  alias OpenTelemetry.Span
  require OpenTelemetry.SemanticConventions.Trace, as: Trace

  use MvOpentelemetry.SpanTracer,
    name: :oban,
    events: [
      [:oban, :job, :start],
      [:oban, :job, :stop],
      [:oban, :job, :exception]
    ]

  def handle_event([:oban, :job, :start], _measurements, meta, opts) do
    %{
      job: %{
        id: id,
        queue: queue,
        worker: worker,
        priority: priority,
        inserted_at: inserted_at,
        scheduled_at: scheduled_at,
        attempt: attempt,
        max_attempts: max_attempts
      }
    } = meta

    inserted_at_string =
      if inserted_at do
        DateTime.to_iso8601(inserted_at)
      end

    attributes = [
      {Trace.messaging_system(), :oban},
      {Trace.messaging_destination(), queue},
      {Trace.messaging_operation(), :process},
      {:"messaging.oban.job_id", id},
      {:"messaging.oban.worker", worker},
      {:"messaging.oban.priority", priority},
      {:"messaging.oban.attempt", attempt},
      {:"messaging.oban.max_attempts", max_attempts},
      {:"messaging.oban.inserted_at", inserted_at_string},
      {:"messaging.oban.scheduled_at", DateTime.to_iso8601(scheduled_at)}
    ]

    attributes = opts[:default_attributes] ++ attributes
    event_name = "#{worker} process"

    OpentelemetryTelemetry.start_telemetry_span(opts[:tracer_id], event_name, meta, %{
      kind: :consumer,
      attributes: attributes
    })

    :ok
  end

  def handle_event([:oban, :job, :stop], _measurements, meta, opts) do
    _ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)
    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
  end

  def handle_event(
        [:oban, :job, :exception],
        _measurements,
        %{stacktrace: stacktrace, error: error} = meta,
        opts
      ) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)

    Span.record_exception(ctx, error, stacktrace)
    Span.set_status(ctx, OpenTelemetry.status(:error, ""))

    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
  end
end
