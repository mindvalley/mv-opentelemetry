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
    |> get("/", %{})

    assert_receive {:span, span(name: "mv_harness.request.get") = span_record}
    attributes = span(span_record, :attributes)

    assert {:"http.status", 200} in attributes
    assert {:"http.method", "GET"} in attributes
    assert attributes[:"http.user_agent"]
    assert attributes[:"http.request_id"]
    assert attributes[:"http.path_params"] == %{}
    assert attributes[:"http.query_params"] == %{}
    assert attributes[:"http.client_ip"]
    assert attributes[:"http.user_agent"] == "Phoenix Test"
    assert attributes[:"http.referer"] == "http://localhost"

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
