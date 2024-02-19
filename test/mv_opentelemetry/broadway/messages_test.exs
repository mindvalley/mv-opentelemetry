defmodule MvOpentelemetry.Broadway.MessagesTest do
  use MvOpentelemetry.OpenTelemetryCase
  alias MvOpentelemetry.Broadway.Messages
  alias MvOpentelemetryHarness.BroadwayDummy

  test "sends otel events to pid" do
    Messages.register_tracer(
      name: :test_broadway_tracer,
      default_attributes: [{"service.component", "test.harness"}]
    )

    BroadwayDummy.start_link()
    ref = BroadwayDummy.test_message(1)
    assert_receive {:ack, ^ref, [%{data: 1}], []}
    assert_receive {:span, span(name: "broadway.processor.start") = processor_start_span}
    assert_receive {:span, span(name: "broadway.processor.message.start")}
    validate_processor_attributes(processor_start_span)
    :ok = :telemetry.detach({:test_broadway_tracer, MvOpentelemetry.Broadway.Messages})
  end

  defp validate_processor_attributes(span_record) do
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    keys = Enum.map(attributes, fn {k, _v} -> k end)

    assert "broadway.index" in keys
    assert "broadway.messages_count" in keys
    assert "broadway.processor_key" in keys
    assert "broadway.stage" in keys
    assert "broadway.topology_name" in keys
    assert "service.component" in keys
  end
end
