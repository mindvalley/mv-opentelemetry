defmodule MvOpentelemetry.LiveViewTest do
  use MvOpentelemetry.OpenTelemetryCase
  import Phoenix.LiveViewTest

  test "sends OpenTelemetry events to pid()", %{conn: conn} do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())
    MvOpentelemetry.LiveView.register_tracer(name: :test_live_view_tracer)

    assert {:ok, _view, html} = live(conn, "/live?live_id=11")
    assert html =~ "LiveLive"

    assert_receive {:span, span(name: "phoenix.live_view.mount") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"live_view.view", MvOpentelemetryHarnessWeb.LiveLive} in attributes
    assert {"live_view.params.live_id", "11"} in attributes

    assert_receive {:span, span(name: "phoenix.live_view.handle_params") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"live_view.view", MvOpentelemetryHarnessWeb.LiveLive} in attributes
    assert {"live_view.params.live_id", "11"} in attributes

    :ok = :telemetry.detach({:test_live_view_tracer, MvOpentelemetry.LiveView})
  end
end
