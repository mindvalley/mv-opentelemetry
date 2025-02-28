defmodule MvOpentelemetry.CowboyTest do
  use MvOpentelemetry.OpenTelemetryCase, async: false

  alias MvOpentelemetryHarnessWeb.Router.Helpers, as: Routes

  setup do
    on_exit(fn -> :telemetry.detach({:opentelemetry_cowboy, :otel_cowboy}) end)
    %{finch: start_supervised!({Finch, name: __MODULE__})}
  end

  test "creates spans on successful HTTP requests" do
    MvOpentelemetry.Cowboy.register_tracer([])

    url = Routes.page_url(MvOpentelemetryHarnessWeb.Endpoint, :index)
    {:ok, %{headers: headers}} = Finch.build(:get, url) |> Finch.request(__MODULE__)
    request_id = :proplists.get_value("x-request-id", headers)

    assert_receive {:span, span(name: :GET) = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    keys = Enum.map(attributes, fn {k, _v} -> k end)

    assert {:"http.response.status_code", 200} in attributes
    assert {:"http.request.method", :GET} in attributes
    assert {:"url.path", "/"} in attributes
    assert {:"user_agent.original", "mint/1.6.2"} in attributes
    assert {:"network.protocol.version", :"1.1"} in attributes
    assert {:"http.response.header.x-request-id", [request_id]} in attributes
    assert :"client.address" in keys
  end

  test "can override attributes" do
    MvOpentelemetry.Cowboy.register_tracer(response_headers: [])
    url = Routes.page_url(MvOpentelemetryHarnessWeb.Endpoint, :index)
    {:ok, _result} = Finch.build(:get, url) |> Finch.request(__MODULE__)

    assert_receive {:span, span(name: :GET) = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    keys = Enum.map(attributes, fn {k, _v} -> k end)

    refute :"http.response.header.x-request-id" in keys
  end

  test "does thing on failure" do
    MvOpentelemetry.Cowboy.register_tracer([])
    path = "/potato/#{System.unique_integer([:positive])}"
    url = "http://localhost:4002" <> path
    {:ok, %{headers: headers}} = Finch.build(:get, url) |> Finch.request(__MODULE__)
    request_id = :proplists.get_value("x-request-id", headers)

    assert_receive {:span, span(name: :GET) = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    keys = Enum.map(attributes, fn {k, _v} -> k end)

    assert {:"http.response.status_code", 404} in attributes
    assert {:"http.request.method", :GET} in attributes
    assert {:"url.path", path} in attributes
    assert {:"user_agent.original", "mint/1.6.2"} in attributes
    assert {:"network.protocol.version", :"1.1"} in attributes
    assert {:"http.response.header.x-request-id", [request_id]} in attributes
    assert :"client.address" in keys
  end
end
