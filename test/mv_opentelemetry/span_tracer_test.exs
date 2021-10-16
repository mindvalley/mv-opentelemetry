defmodule MvOpentelemetry.SpanTracerTest do
  use MvOpentelemetry.OpenTelemetryCase

  alias MvOpentelemetry.CustomSpanTracer

  test "it captures the event" do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())
    CustomSpanTracer.register_tracer()

    :telemetry.span([:my_event, :do_stuff], %{name: "custom"}, fn ->
      {:ok, %{result: :success}}
    end)

    assert_receive {:span, span_record}
    assert "my_event.do_stuff" == span(span_record, :name)
    attributes = span(span_record, :attributes)
    assert {:"my_event.name", "custom"} in attributes
    assert {:"my_event.result", :success} in attributes

    :ok = :telemetry.detach({CustomSpanTracer, CustomSpanTracer})
  end

  test "it captures the exception" do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())
    CustomSpanTracer.register_tracer()

    try do
      CustomSpanTracer.raise_test_error()
    rescue
      RuntimeError ->
        assert_receive {:span, span_record}
        assert "my_event.do_stuff" == span(span_record, :name)
        attributes = span(span_record, :attributes)
        assert {:error, true} in attributes
        assert {:kind, :error} in attributes
        :ok = :telemetry.detach({CustomSpanTracer, CustomSpanTracer})
    end
  end
end
