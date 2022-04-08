defmodule MvOpentelemetry.Dataloader do
  @moduledoc false

  use MvOpentelemetry.SpanTracer,
    events: [
      [:dataloader, :source, :run, :start],
      [:dataloader, :source, :run, :stop],
      [:dataloader, :source, :batch, :run, :stop],
      [:dataloader, :source, :batch, :run, :start]
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

  def handle_event([:dataloader, :source, :batch, :run, :start], _measurements, meta, opts) do
    event_name = "dataloader.source.batch.run"

    parent_context = OpentelemetryProcessPropagator.fetch_parent_ctx(1, :"$callers")
    attach_context(parent_context)

    OpentelemetryTelemetry.start_telemetry_span(__MODULE__, event_name, meta, %{})
    |> Span.set_attributes(opts[:default_attributes])

    :ok
  end

  def handle_event([:dataloader, :source, :batch, :run, :stop], _measurements, meta, _opts) do
    OpentelemetryTelemetry.end_telemetry_span(__MODULE__, meta)
    :ok
  end

  defp attach_context(:undefined), do: :ok
  defp attach_context(context), do: OpenTelemetry.Ctx.attach(context)
end
