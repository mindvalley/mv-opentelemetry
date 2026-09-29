defmodule MvOpentelemetry.ReqTest do
  use MvOpentelemetry.OpenTelemetryCase, async: false

  def setup_bypass(_) do
    bypass = Bypass.open()
    %{bypass: bypass, bypass_url: bypass_url(bypass)}
  end

  defp bypass_url(%Bypass{port: port}), do: "http://localhost:#{port}/"

  setup [:setup_bypass]

  test "emits events on success", %{bypass: bypass, bypass_url: bypass_url} do
    MvOpentelemetry.Finch.register_tracer(
      name: :test_req_tracer,
      default_attributes: [{"service.component", "req.harness"}]
    )

    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 200, "")
    end)

    Req.get(bypass_url)

    assert_receive {:span, span(name: "GET") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert :client == span(span_record, :kind)

    assert {:"http.response.status_code", 200} in attributes
    assert {:"http.response.header.content-length", ["0"]} in attributes
    assert {:"server.address", "localhost"} in attributes
    assert {:"http.request.method", "GET"} in attributes
    assert {:"url.path", "/"} in attributes
    assert {:"url.full", bypass_url} in attributes
    assert {"service.component", "req.harness"} in attributes

    :ok = :telemetry.detach({:test_req_tracer, MvOpentelemetry.Finch})
  end

  test "emits events on failure" do
    MvOpentelemetry.Finch.register_tracer(
      name: :test_req_tracer,
      default_attributes: [{"service.component", "req.harness"}]
    )

    path = "/potato/#{System.unique_integer([:positive])}"
    url = "http://localhost:10000" <> path

    Req.get(url, retry: false)

    assert_receive {:span, span(name: "GET") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert :client == span(span_record, :kind)

    keys = Enum.map(attributes, fn {k, _} -> k end)

    refute :"http.response.status_code" in keys
    assert {:"http.request.method", "GET"} in attributes
    assert {:"url.path", path} in attributes
    assert {:"url.full", url} in attributes
    assert {"service.component", "req.harness"} in attributes

    :ok = :telemetry.detach({:test_req_tracer, MvOpentelemetry.Finch})
  end
end
