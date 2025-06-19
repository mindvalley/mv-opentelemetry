defmodule MvOpentelemetry.LiveViewTest do
  use MvOpentelemetry.OpenTelemetryCase
  import Phoenix.LiveViewTest

  test "does not set query params if none given", %{conn: conn} do
    MvOpentelemetry.LiveView.register_tracer(name: :test_live_view_tracer)

    assert {:ok, _view, html} = live(conn, "/live?live_id=11")
    assert html =~ "LiveLive"

    assert_receive {:span, span(name: "live_view.disconnected.mount") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"live_view.view", MvOpentelemetryHarnessWeb.LiveLive} in attributes
    assert {"live_view.connected", false} in attributes
    refute {"live_view.params.live_id", "11"} in attributes

    :ok = :telemetry.detach({:test_live_view_tracer, MvOpentelemetry.LiveView})
  end

  test "sends OpenTelemetry events to pid()", %{conn: conn} do
    MvOpentelemetry.LiveView.register_tracer(
      name: :test_live_view_tracer,
      default_attributes: [{"potatoeh", "potatoe"}]
    )

    assert {:ok, _view, html} = live(conn, "/live?live_id=11")
    assert html =~ "LiveLive"

    assert_receive {:span, span(name: "live_view.disconnected.mount") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"live_view.view", MvOpentelemetryHarnessWeb.LiveLive} in attributes
    assert {"potatoeh", "potatoe"} in attributes
    assert {"live_view.connected", false} in attributes

    assert_receive {:span, span(name: "live_view.disconnected.handle_params") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"live_view.view", MvOpentelemetryHarnessWeb.LiveLive} in attributes
    assert {"potatoeh", "potatoe"} in attributes
    assert {"live_view.connected", false} in attributes

    assert_receive {:span, span(name: "live_view.connected.mount") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"live_view.view", MvOpentelemetryHarnessWeb.LiveLive} in attributes
    assert {"potatoeh", "potatoe"} in attributes
    assert {"live_view.connected", true} in attributes

    assert_receive {:span, span(name: "live_view.connected.handle_params") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"live_view.view", MvOpentelemetryHarnessWeb.LiveLive} in attributes
    assert {"potatoeh", "potatoe"} in attributes
    assert {"live_view.connected", true} in attributes

    :ok = :telemetry.detach({:test_live_view_tracer, MvOpentelemetry.LiveView})
  end

  test "allows for setting query params whitelist", %{conn: conn} do
    MvOpentelemetry.LiveView.register_tracer(
      name: :test_live_view_tracer,
      query_params_whitelist: ["user_id"]
    )

    assert {:ok, _view, html} = live(conn, "/live?live_id=11&user_id=12")
    assert html =~ "LiveLive"

    assert_receive {:span, span(name: "live_view.disconnected.mount") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"live_view.view", MvOpentelemetryHarnessWeb.LiveLive} in attributes
    refute {"live_view.params.live_id", "11"} in attributes
    assert {"live_view.params.user_id", "12"} in attributes

    assert_receive {:span, span(name: "live_view.disconnected.handle_params") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"live_view.view", MvOpentelemetryHarnessWeb.LiveLive} in attributes
    refute {"live_view.params.live_id", "11"} in attributes
    assert {"live_view.params.user_id", "12"} in attributes

    :ok = :telemetry.detach({:test_live_view_tracer, MvOpentelemetry.LiveView})
  end
end
