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
    assert_receive {:span, span_record_1}
    assert_receive {:span, span_record_2}

    assert Enum.member?(
             ["broadway.processor.start", "broadway.processor.message.start"],
             span(span_record_1, :name)
           )

    assert Enum.member?(
             ["broadway.processor.start", "broadway.processor.message.start"],
             span(span_record_2, :name)
           )

    case span(span_record_1, :name) do
      "broadway.processor.start" ->
        validate_processor_attributes(span_record_1)

      _ ->
        :ok
    end

    case span(span_record_2, :name) do
      "broadway.processor.start" ->
        validate_processor_attributes(span_record_2)

      _ ->
        :ok
    end

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
