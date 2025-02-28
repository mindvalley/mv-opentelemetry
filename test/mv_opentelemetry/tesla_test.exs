defmodule MvOpentelemetry.TeslaTest do
  use MvOpentelemetry.OpenTelemetryCase, async: false

  require OpenTelemetry.Tracer, as: Tracer

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

  describe "get_content_length/1" do
    test "handles 'content-length' header" do
      result = {:ok, %{headers: [{"content-length", "123"}]}}
      expected_response = %{"http.response.header.content-length": ["123"]}
      assert MvOpentelemetry.Tesla.get_content_length(result) == expected_response
    end

    test "handles missing 'content-length' header" do
      result = {:ok, %{headers: []}}
      assert MvOpentelemetry.Tesla.get_content_length(result) == %{}
    end

    test "handles error case" do
      result = :yeet
      assert MvOpentelemetry.Tesla.get_content_length(result) == %{}
    end
  end

  test "emits events on success", %{bypass: bypass, bypass_url: bypass_url, tesla_client: client} do
    MvOpentelemetry.Tesla.register_tracer(
      name: :test_tesla_tracer,
      default_attributes: [{"service.component", "tesla.harness"}]
    )

    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 200, "")
    end)

    Tesla.get(client, "/")

    assert_receive {:span, span(name: "GET") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert :client == span(span_record, :kind)

    assert {:"http.response.status_code", 200} in attributes
    assert {:"server.address", "localhost"} in attributes
    assert {:"http.request.method", "GET"} in attributes
    assert {:"url.path", "/"} in attributes
    assert {:"url.full", bypass_url} in attributes
    assert {"service.component", "tesla.harness"} in attributes

    :ok = :telemetry.detach({:test_tesla_tracer, MvOpentelemetry.Tesla})
  end

  test "propagates telemetry context in Tesla from other processes", %{
    tesla_client: client,
    bypass: bypass,
    bypass_url: bypass_url
  } do
    MvOpentelemetry.Tesla.register_tracer(
      name: :test_tesla_tracer,
      default_attributes: [{"service.component", "tesla.harness"}]
    )

    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 200, "")
    end)

    Tracer.with_span "root span", %{is_root: true} do
      task =
        Task.async(fn ->
          Tesla.get(client, "/")
        end)

      Task.await(task)
    end

    assert_receive {:span, span(name: "root span") = span_record}
    assert_receive {:span, span(name: "GET") = child_span_record}
    {:attributes, _, _, _, attributes} = span(child_span_record, :attributes)

    assert :client == span(child_span_record, :kind)
    assert {:"http.response.status_code", 200} in attributes
    assert {:"server.address", "localhost"} in attributes
    assert {:"http.request.method", "GET"} in attributes
    assert {:"url.path", "/"} in attributes
    assert {:"url.full", bypass_url} in attributes
    assert {"service.component", "tesla.harness"} in attributes

    assert span(span_record, :span_id) == span(child_span_record, :parent_span_id)

    :ok = :telemetry.detach({:test_tesla_tracer, MvOpentelemetry.Tesla})
  end

  test "emits events on failure", %{tesla_client: client} do
    MvOpentelemetry.Tesla.register_tracer(
      name: :test_tesla_tracer,
      default_attributes: [{"service.component", "tesla.harness"}]
    )

    path = "/potato/#{System.unique_integer([:positive])}"
    url = "http://localhost:10000" <> path

    Tesla.get(client, url)

    assert_receive {:span, span(name: "GET") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert :client == span(span_record, :kind)

    keys = Enum.map(attributes, fn {k, _} -> k end)

    refute :"http.response.status_code" in keys
    assert {:"server.address", "localhost"} in attributes
    assert {:"http.request.method", "GET"} in attributes
    assert {:"url.path", path} in attributes
    assert {:"url.full", url} in attributes
    assert {"service.component", "tesla.harness"} in attributes

    :ok = :telemetry.detach({:test_tesla_tracer, MvOpentelemetry.Tesla})
  end
end
