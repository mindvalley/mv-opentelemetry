defmodule MvOpentelemetry.FinchTest do
  use MvOpentelemetry.OpenTelemetryCase

  alias MvOpentelemetryHarnessWeb.Router.Helpers, as: Routes

  def setup_bypass(_) do
    bypass = Bypass.open()
    %{bypass: bypass, bypass_url: bypass_url(bypass)}
  end

  defp bypass_url(%Bypass{port: port}), do: "http://localhost:#{port}/"

  def setup_finch(_) do
    {:ok, finch} = Finch.start_link(name: TestFinch)
    %{finch: finch}
  end

  setup [:setup_bypass, :setup_finch]

  describe "get_content_length/1" do
    test "handles 'content-length' header" do
      result = {:ok, %{headers: [{"content-length", "123"}]}}
      assert MvOpentelemetry.Finch.get_content_length(result) == 123
    end

    test "handles missing 'content-length' header" do
      result = {:ok, %{headers: []}}
      assert MvOpentelemetry.Finch.get_content_length(result) == nil
    end

    test "handles invalid 'content-length' header" do
      result = {:ok, %{headers: [{"content-length", "abc"}]}}
      assert MvOpentelemetry.Finch.get_content_length(result) == nil
    end

    test "handles error case" do
      result = :yeet
      assert MvOpentelemetry.Finch.get_content_length(result) == nil
    end
  end

  test "emits events on success", %{bypass: bypass, bypass_url: bypass_url} do
    MvOpentelemetry.Finch.register_tracer(
      name: :test_finch_tracer,
      default_attributes: [{"service.component", "test.harness"}]
    )

    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 200, "")
    end)

    Finch.build(:get, bypass_url) |> Finch.request(TestFinch)

    assert_receive {:span, span(name: "HTTP GET") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert :client == span(span_record, :kind)

    assert {:"http.status_code", 200} in attributes
    assert {:"net.peer.name", "localhost"} in attributes
    assert {:"http.method", "GET"} in attributes
    assert {:"http.target", "/"} in attributes
    assert {:"http.url", bypass_url} in attributes
    assert {"service.component", "test.harness"} in attributes

    :ok = :telemetry.detach({:test_finch_tracer, MvOpentelemetry.Finch})
  end

  test "emits events on failure" do
    MvOpentelemetry.Finch.register_tracer(
      name: :test_finch_tracer,
      default_attributes: [{"service.component", "test.harness"}]
    )

    url = Routes.page_url(MvOpentelemetryHarnessWeb.Endpoint, :index)

    Finch.build(:get, url) |> Finch.request(TestFinch)

    assert_receive {:span, span(name: "HTTP GET") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert :client == span(span_record, :kind)

    keys = Enum.map(attributes, fn {k, _} -> k end)

    refute :"http.status_code" in keys
    assert {:"http.method", "GET"} in attributes
    assert {:"http.target", "/"} in attributes
    assert {:"http.url", url} in attributes
    assert {"service.component", "test.harness"} in attributes

    :ok = :telemetry.detach({:test_finch_tracer, MvOpentelemetry.Finch})
  end
end
