defmodule MvOpentelemetry.TeslaTest do
  use MvOpentelemetry.OpenTelemetryCase

  alias MvOpentelemetryHarnessWeb.Router.Helpers, as: Routes

  def setup_bypass(_) do
    bypass = Bypass.open()
    %{bypass: bypass, bypass_url: bypass_url(bypass)}
  end

  defp bypass_url(%Bypass{port: port}), do: "http://localhost:#{port}/"

  def setup_tesla_client(context) do
    middleware = [
      {Tesla.Middleware.BaseUrl, bypass_url(context.bypass)},
      Tesla.Middleware.JSON,
      Tesla.Middleware.Telemetry
    ]

    %{tesla_client: Tesla.client(middleware)}
  end

  setup [:setup_bypass, :setup_tesla_client]

  test "emits events on success", %{bypass: bypass, bypass_url: bypass_url, tesla_client: client} do
    MvOpentelemetry.Tesla.register_tracer(
      name: :test_tesla_tracer,
      default_attributes: [{"service.component", "test.harness"}]
    )

    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 200, "")
    end)

    Tesla.get(client, "/")

    assert_receive {:span, span(name: "HTTP get") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert :client == span(span_record, :kind)

    assert {:"http.status_code", 200} in attributes
    assert {:"http.method", :get} in attributes
    assert {:"http.target", "/"} in attributes
    assert {:"http.url", bypass_url} in attributes
    assert {"service.component", "test.harness"} in attributes

    :ok = :telemetry.detach({:test_tesla_tracer, MvOpentelemetry.Tesla})
  end

  test "emits events on failure", %{tesla_client: client} do
    MvOpentelemetry.Tesla.register_tracer(
      name: :test_tesla_tracer,
      default_attributes: [{"service.component", "test.harness"}]
    )

    url = Routes.page_url(MvOpentelemetryHarnessWeb.Endpoint, :index)

    Tesla.get(client, url)

    assert_receive {:span, span(name: "HTTP get") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert :client == span(span_record, :kind)

    keys = Enum.map(attributes, fn {k, _} -> k end)

    refute :"http.status_code" in keys
    assert {:"http.method", :get} in attributes
    assert {:"http.target", "/"} in attributes
    assert {:"http.url", url} in attributes
    assert {"service.component", "test.harness"} in attributes

    :ok = :telemetry.detach({:test_tesla_tracer, MvOpentelemetry.Tesla})
  end
end
