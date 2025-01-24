defmodule MvOpentelemetry.ObanTest do
  use MvOpentelemetry.OpenTelemetryCase

  test "perform_job/1 emits span events" do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())

    MvOpentelemetry.Oban.register_tracer(
      name: :test_oban_tracer,
      default_attributes: [{"service.component", :academy}]
    )

    Oban.Testing.perform_job(MvOpentelemetryHarness.Oban.Job, %{},
      repo: MvOpentelemetryHarness.Repo
    )

    assert_receive {:span, span(name: "MvOpentelemetryHarness.Oban.Job process") = span_record}

    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {:"messaging.destination", "events"} in attributes
    assert {:"messaging.oban.worker", "MvOpentelemetryHarness.Oban.Job"} in attributes
    assert {:"messaging.system", :oban} in attributes
    assert {:"messaging.oban.attempt", 1} in attributes
    assert {:"messaging.oban.priority", nil} in attributes
    assert {:"messaging.system", :oban} in attributes
    assert {"service.component", :academy} in attributes

    assert Map.get(attributes, :"messaging.oban.inserted_at")

    :ok = :telemetry.detach({:test_oban_tracer, MvOpentelemetry.Oban})
  end
end
