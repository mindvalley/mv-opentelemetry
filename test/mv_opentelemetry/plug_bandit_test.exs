defmodule MvOpentelemetry.PlugBanditTest do
  use MvOpentelemetry.OpenTelemetryCase, async: false

  alias MvOpentelemetryHarnessWeb.Router.Helpers, as: Routes

  setup do
    Application.stop(:mv_opentelemetry_harness)

    env = Application.get_env(:mv_opentelemetry_harness, MvOpentelemetryHarnessWeb.Endpoint)
    new_env = Keyword.merge(env, adapter: Bandit.PhoenixAdapter)
    Application.put_env(:mv_opentelemetry_harness, MvOpentelemetryHarnessWeb.Endpoint, new_env)

    :ok = Application.start(:mv_opentelemetry_harness)

    on_exit(fn ->
      :ok = :telemetry.detach({OpentelemetryBandit, :otel_bandit})
      :ok = :telemetry.detach({[:harness, :request], MvOpentelemetry.Plug, :handle_start_event})
      :ok = :telemetry.detach({[:harness, :request], MvOpentelemetry.Plug, :handle_router_event})

      Application.stop(:mv_opentelemetry_harness)
      Application.put_env(:mv_opentelemetry_harness, MvOpentelemetryHarnessWeb.Endpoint, env)
      :ok = Application.start(:mv_opentelemetry_harness)
    end)

    :ok = MvOpentelemetry.Bandit.register_tracer([])

    :ok =
      MvOpentelemetry.Plug.register_tracer(span_prefix: [:harness, :request], adapter: :bandit)

    %{finch: start_supervised!({Finch, name: __MODULE__})}
  end

  test "handles successful request" do
    url = Routes.page_url(MvOpentelemetryHarnessWeb.Endpoint, :index)

    {:ok, %{headers: headers}} =
      Finch.build(:get, url, [{"user-agent", "Plug Test"}, {"referer", "http://localhost"}])
      |> Finch.request(__MODULE__)

    request_id = :proplists.get_value("x-request-id", headers)

    assert_receive {:span, span(name: "GET /") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    keys = Enum.map(attributes, fn {k, _v} -> k end)

    assert {:"http.response.status_code", 200} in attributes
    assert {:"http.request.method", :GET} in attributes
    assert {:"url.path", "/"} in attributes
    assert {:"user_agent.original", "Plug Test"} in attributes
    assert {:"http.request.header.referer", ["http://localhost"]} in attributes
    assert {:"http.response.header.x-request-id", [request_id]} in attributes
    assert :"client.address" in keys
  end

  test "handles query params" do
    url = Routes.page_url(MvOpentelemetryHarnessWeb.Endpoint, :index, %{query: "Params"})

    {:ok, %{headers: headers}} =
      Finch.build(:get, url, [{"user-agent", "Plug Test"}, {"referer", "http://localhost"}])
      |> Finch.request(__MODULE__)

    request_id = :proplists.get_value("x-request-id", headers)

    assert_receive {:span, span(name: "GET /") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    keys = Enum.map(attributes, fn {k, _v} -> k end)

    assert {:"http.response.status_code", 200} in attributes
    assert {:"http.request.method", :GET} in attributes
    assert {:"url.path", "/"} in attributes
    assert {:"url.query", "query=Params"} in attributes
    assert {:"user_agent.original", "Plug Test"} in attributes
    assert {:"http.request.header.referer", ["http://localhost"]} in attributes
    assert {:"http.response.header.x-request-id", [request_id]} in attributes
    assert :"client.address" in keys
  end

  test "handles 404" do
    url = "http://localhost:4002/404"

    {:ok, %{headers: headers}} =
      Finch.build(:get, url, [{"user-agent", "Plug Test"}, {"referer", "http://localhost"}])
      |> Finch.request(__MODULE__)

    request_id = :proplists.get_value("x-request-id", headers)

    assert_receive {:span, span(name: :GET) = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    keys = Enum.map(attributes, fn {k, _v} -> k end)

    assert {:"http.response.status_code", 404} in attributes
    assert {:"http.request.method", :GET} in attributes
    assert {:"url.path", "/404"} in attributes
    assert {:"user_agent.original", "Plug Test"} in attributes
    assert {:"http.request.header.referer", ["http://localhost"]} in attributes
    assert {:"http.response.header.x-request-id", [request_id]} in attributes
    assert :"client.address" in keys
  end

  test "handles timeout" do
    url = "http://localhost:4002/timeout"

    {:error, %Mint.TransportError{reason: :timeout}} =
      Finch.build(:get, url, [{"user-agent", "Plug Test"}, {"referer", "http://localhost"}])
      |> Finch.request(__MODULE__, receive_timeout: 100)

    assert_receive {:span, span(name: "GET /timeout") = span_record}, 1000
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    keys = Enum.map(attributes, fn {k, _v} -> k end)

    assert {:"http.request.method", :GET} in attributes
    assert {:"url.path", "/timeout"} in attributes
    assert {:"user_agent.original", "Plug Test"} in attributes
    assert {:"http.request.header.referer", ["http://localhost"]} in attributes
    assert :"client.address" in keys
  end

  test "handles 500" do
    url = "http://localhost:4002/500"

    {:ok, _} =
      Finch.build(:get, url, [{"user-agent", "Plug Test"}, {"referer", "http://localhost"}])
      |> Finch.request(__MODULE__)

    assert_receive {:span, span(name: "GET /500") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    keys = Enum.map(attributes, fn {k, _v} -> k end)

    assert {:"http.response.status_code", 500} in attributes
    assert {:"http.request.method", :GET} in attributes
    assert {:"url.path", "/500"} in attributes
    assert {:"user_agent.original", "Plug Test"} in attributes
    assert {:"http.request.header.referer", ["http://localhost"]} in attributes
    assert :"client.address" in keys
  end

  test "does not record headers in error cases" do
    url = "http://localhost:4002/500"

    {:ok, _} =
      Finch.build(:get, url, [{"user-agent", "Plug Test"}, {"referer", "http://localhost"}])
      |> Finch.request(__MODULE__)

    assert_receive {:span, span(name: "GET /500") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    keys = Enum.map(attributes, fn {k, _v} -> k end)

    refute :"http.response.header.x-request-id" in keys

    assert {:"http.response.status_code", 500} in attributes
    assert {:"http.request.method", :GET} in attributes
    assert {:"url.path", "/500"} in attributes
    assert {:"user_agent.original", "Plug Test"} in attributes
    assert {:"http.request.header.referer", ["http://localhost"]} in attributes
    assert :"client.address" in keys
  end

  test "adds router attributes" do
    url = Routes.page_url(MvOpentelemetryHarnessWeb.Endpoint, :index)

    {:ok, _any} =
      Finch.build(:get, url, [{"user-agent", "Plug Test"}, {"referer", "http://localhost"}])
      |> Finch.request(__MODULE__)

    assert_receive {:span, span(name: "GET /") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {:"phoenix.action", :index} in attributes
    assert {:"phoenix.plug", MvOpentelemetryHarnessWeb.PageController} in attributes
  end
end
