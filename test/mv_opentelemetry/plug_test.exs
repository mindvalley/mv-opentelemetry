defmodule MvOpentelemetry.PlugTest do
  use MvOpentelemetry.OpenTelemetryCase

  test "handles successful requests in stories-specific context", %{conn: conn} do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())

    MvOpentelemetry.Plug.register_tracer(
      tracer_id: :test_plug_tracer,
      span_prefix: [:harness, :request],
      name_prefix: [:mv_harness, :request]
    )

    conn
    |> put_req_header("user-agent", "Phoenix Test")
    |> put_req_header("referer", "http://localhost")
    |> get("/?query=1234&user_id=", %{})

    assert_receive {:span, span(name: "mv_harness.request.get") = span_record}
    attributes = span(span_record, :attributes)
    keys = Enum.map(attributes, fn {k, _v} -> k end)

    assert {"http.status", 200} in attributes
    assert {"http.method", "GET"} in attributes
    assert {"http.query_params.query", "1234"} in attributes
    assert {"http.query_params.user_id", ""} in attributes
    assert {"http.user_agent", "Phoenix Test"} in attributes
    assert {"http.referer", "http://localhost"} in attributes
    assert "http.request_id" in keys
    assert "http.client_ip" in keys

    :ok = :telemetry.detach({:test_plug_tracer, MvOpentelemetry.Plug, :handle_start_event})
    :ok = :telemetry.detach({:test_plug_tracer, MvOpentelemetry.Plug, :handle_stop_event})
  end

  test "defaults to [:phoenix, :endpoint] for span prefix", %{conn: conn} do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())
    MvOpentelemetry.Plug.register_tracer(tracer_id: :test_new_plug_tracer)
    get(conn, "/", %{})
    assert_receive {:span, span(name: "phoenix.endpoint.get")}

    :ok = :telemetry.detach({:test_new_plug_tracer, MvOpentelemetry.Plug, :handle_start_event})
    :ok = :telemetry.detach({:test_new_plug_tracer, MvOpentelemetry.Plug, :handle_stop_event})
  end
end
