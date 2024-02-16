defmodule MvOpentelemetry.SpanTracerTest do
  use MvOpentelemetry.OpenTelemetryCase

  alias MvOpentelemetry.CustomSpanTracer

  test "it captures the event" do
    CustomSpanTracer.register_tracer()

    :telemetry.span([:my_event, :do_stuff], %{name: "custom"}, fn ->
      {:ok, %{result: :success}}
    end)

    assert_receive {:span, span(name: "my_event.do_stuff") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    assert {:"my_event.name", "custom"} in attributes
    assert {:"my_event.result", :success} in attributes

    :ok = :telemetry.detach({CustomSpanTracer, CustomSpanTracer})
  end

  test "it captures the exception" do
    CustomSpanTracer.register_tracer()

    try do
      CustomSpanTracer.raise_test_error()
    rescue
      RuntimeError ->
        assert_receive {:span, span(name: "my_event.do_stuff") = span_record}
        {:attributes, _, _, _, attributes} = span(span_record, :attributes)
        assert {:error, true} in attributes
        assert {:kind, :error} in attributes
        :ok = :telemetry.detach({CustomSpanTracer, CustomSpanTracer})
    end
  end
end
