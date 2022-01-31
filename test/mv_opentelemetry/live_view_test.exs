defmodule MvOpentelemetry.LiveViewTest do
  use MvOpentelemetry.OpenTelemetryCase
  import Phoenix.LiveViewTest

  test "sends OpenTelemetry events to pid()", %{conn: conn} do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())

    MvOpentelemetry.LiveView.register_tracer(
      name: :test_live_view_tracer,
      default_attributes: [{"potatoeh", "potatoe"}]
    )

    assert {:ok, _view, html} = live(conn, "/live?live_id=11")
    assert html =~ "LiveLive"

    assert_receive {:span, span(name: "phoenix.live_view.mount") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"live_view.view", MvOpentelemetryHarnessWeb.LiveLive} in attributes
    assert {"potatoeh", "potatoe"} in attributes
    assert {"live_view.params.live_id", "11"} in attributes

    assert_receive {:span, span(name: "phoenix.live_view.handle_params") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"live_view.view", MvOpentelemetryHarnessWeb.LiveLive} in attributes
    assert {"live_view.params.live_id", "11"} in attributes
    assert {"potatoeh", "potatoe"} in attributes

    :ok = :telemetry.detach({:test_live_view_tracer, MvOpentelemetry.LiveView})
  end

  test "allows for setting query params whitelist", %{conn: conn} do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())

    MvOpentelemetry.LiveView.register_tracer(
      name: :test_live_view_tracer,
      query_params_whitelist: ["user_id"]
    )

    assert {:ok, _view, html} = live(conn, "/live?live_id=11&user_id=12")
    assert html =~ "LiveLive"

    assert_receive {:span, span(name: "phoenix.live_view.mount") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"live_view.view", MvOpentelemetryHarnessWeb.LiveLive} in attributes
    refute {"live_view.params.live_id", "11"} in attributes
    assert {"live_view.params.user_id", "12"} in attributes

    assert_receive {:span, span(name: "phoenix.live_view.handle_params") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"live_view.view", MvOpentelemetryHarnessWeb.LiveLive} in attributes
    refute {"live_view.params.live_id", "11"} in attributes
    assert {"live_view.params.user_id", "12"} in attributes

    :ok = :telemetry.detach({:test_live_view_tracer, MvOpentelemetry.LiveView})
  end
end
