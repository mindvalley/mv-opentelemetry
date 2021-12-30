defmodule MvOpentelemetry.EctoTest do
  use MvOpentelemetry.OpenTelemetryCase

  test "sends otel events to pid" do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())

    MvOpentelemetry.Ecto.register_tracer(
      tracer_id: :test_ecto_tracer,
      span_prefix: [:mv_opentelemetry_harness, :repo]
    )

    MvOpentelemetryHarness.Page.all() |> MvOpentelemetryHarness.Repo.all()

    assert_receive {:span, span_record}
    assert "mv_opentelemetry_harness.repo.pages" == span(span_record, :name)
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    keys = Enum.map(attributes, fn {k, _v} -> k end)

    assert {"db.source", "pages"} in attributes
    assert {"db.type", :sql} in attributes
    assert "db.statement" in keys
    assert "db.instance" in keys
    assert "db.url" in keys
    assert "db.total_time_microseconds" in keys

    :ok =
      :telemetry.detach({[:mv_opentelemetry_harness, :repo], MvOpentelemetry.Ecto, :handle_event})
  end

  test "raises when span_prefix is not given" do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())

    assert_raise MvOpentelemetry.Error, "span_prefix is required", fn ->
      MvOpentelemetry.Ecto.register_tracer([])
    end

    {:error, :not_found} =
      :telemetry.detach({[:mv_opentelemetry_harness, :repo], MvOpentelemetry.Ecto, :handle_event})
  end
end
