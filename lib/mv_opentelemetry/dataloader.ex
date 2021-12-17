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
  def handle_event([:dataloader, :source, :run, :start], _measurements, meta, _opts) do
    event_name = "dataloader.source.run"
    OpentelemetryTelemetry.start_telemetry_span(__MODULE__, event_name, meta, %{})

    :ok
  end

  def handle_event([:dataloader, :source, :run, :stop], _measurements, meta, _opts) do
    OpentelemetryTelemetry.end_telemetry_span(__MODULE__, meta)
    :ok
  end

  def handle_event([:dataloader, :source, :batch, :run, :start], _measurements, meta, _opts) do
    event_name = "dataloader.source.batch.run"
    OpentelemetryTelemetry.start_telemetry_span(__MODULE__, event_name, meta, %{})

    :ok
  end

  def handle_event([:dataloader, :source, :batch, :run, :stop], _measurements, meta, _opts) do
    OpentelemetryTelemetry.end_telemetry_span(__MODULE__, meta)
    :ok
  end
end
