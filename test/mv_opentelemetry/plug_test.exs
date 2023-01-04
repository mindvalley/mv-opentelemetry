defmodule MvOpentelemetry.PlugTest do
  use MvOpentelemetry.OpenTelemetryCase

  test "handles successful requests in stories-specific context", %{conn: conn} do
    MvOpentelemetry.Plug.register_tracer(
      span_prefix: [:harness, :request],
      default_attributes: [{"service.component", "test.harness"}]
    )

    conn
    |> put_req_header("user-agent", "Phoenix Test")
    |> put_req_header("referer", "http://localhost")
    |> get("/?query=1234&user_id=", %{})

    assert_receive {:span, span(name: "HTTP GET") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    keys = Enum.map(attributes, fn {k, _v} -> k end)

    assert {:"http.status", 200} in attributes
    assert {:"http.status_code", 200} in attributes
    assert {:"http.method", "GET"} in attributes
    assert {:"http.flavor", ""} in attributes
    assert {:"http.host", "www.example.com"} in attributes
    assert {:"net.peer.name", "www.example.com"} in attributes
    assert {:"http.target", "/"} in attributes
    assert {"service.component", "test.harness"} in attributes
    assert {"http.query_params.query", "1234"} in attributes
    assert {"http.query_params.user_id", ""} in attributes
    assert {:"http.user_agent", "Phoenix Test"} in attributes
    assert {"http.referer", "http://localhost"} in attributes
    assert {:"net.transport", "IP.TCP"} in attributes
    assert "http.request_id" in keys
    assert :"http.client_ip" in keys
    assert "net.peer.ip" in keys
    assert "net.peer.port" in keys

    :ok = :telemetry.detach({[:harness, :request], MvOpentelemetry.Plug, :handle_start_event})
    :ok = :telemetry.detach({[:harness, :request], MvOpentelemetry.Plug, :handle_stop_event})
  end

  test "allows for setting a force trace header", %{conn: conn} do
    MvOpentelemetry.Plug.register_tracer(span_prefix: [:harness, :request])

    conn
    |> put_req_header("x-force-trace", "true")
    |> get("/", %{})

    assert_receive {:span, span(name: "HTTP GET") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    assert {"force_trace", true} in attributes

    conn
    |> put_req_header("x-force-trace", "anything else")
    |> get("/", %{})

    assert_receive {:span, span(name: "HTTP GET") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    refute {"force_trace", true} in attributes

    :ok = :telemetry.detach({[:harness, :request], MvOpentelemetry.Plug, :handle_start_event})
    :ok = :telemetry.detach({[:harness, :request], MvOpentelemetry.Plug, :handle_stop_event})
  end

  test "allows for setting query params whitelist", %{conn: conn} do
    MvOpentelemetry.Plug.register_tracer(
      span_prefix: [:harness, :request],
      query_params_whitelist: ["user_id"],
      default_attributes: [{"service.component", "test.harness"}]
    )

    conn
    |> put_req_header("user-agent", "Phoenix Test")
    |> put_req_header("referer", "http://localhost")
    |> get("/?query=1234&user_id=1233", %{})

    assert_receive {:span, span(name: "HTTP GET") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    keys = Enum.map(attributes, fn {k, _v} -> k end)

    assert {:"http.status", 200} in attributes
    assert {:"http.status_code", 200} in attributes
    assert {:"http.method", "GET"} in attributes
    assert {:"http.flavor", ""} in attributes
    assert {:"http.target", "/"} in attributes
    assert {"service.component", "test.harness"} in attributes
    refute {"http.query_params.query", "1234"} in attributes
    assert {"http.query_params.user_id", "1233"} in attributes
    assert {:"http.user_agent", "Phoenix Test"} in attributes
    assert {"http.referer", "http://localhost"} in attributes
    assert {:"net.transport", "IP.TCP"} in attributes
    assert "http.request_id" in keys
    assert :"http.client_ip" in keys
    assert "net.peer.ip" in keys
    assert "net.peer.port" in keys

    :ok = :telemetry.detach({[:harness, :request], MvOpentelemetry.Plug, :handle_start_event})
    :ok = :telemetry.detach({[:harness, :request], MvOpentelemetry.Plug, :handle_stop_event})
  end
end
