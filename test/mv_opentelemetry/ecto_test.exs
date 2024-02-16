defmodule MvOpentelemetry.EctoTest do
  use MvOpentelemetry.OpenTelemetryCase
  alias MvOpentelemetryHarness.Page
  alias MvOpentelemetryHarness.Repo

  test "sends otel events to pid" do
    MvOpentelemetry.Ecto.register_tracer(
      tracer_id: :test_ecto_tracer,
      span_prefix: [:mv_opentelemetry_harness, :repo],
      default_attributes: [{"service.component", "test.harness"}]
    )

    Page.all() |> Repo.all()

    assert_receive {:span, span(name: "mv_opentelemetry_harness.repo.pages") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    keys = Enum.map(attributes, fn {k, _v} -> k end)

    assert {"db.source", "pages"} in attributes
    assert {"db.type", :sql} in attributes
    assert {"service.component", "test.harness"} in attributes
    assert "db.statement" in keys
    assert "db.instance" in keys
    assert "db.url" in keys
    assert "db.total_time_microseconds" in keys

    :ok =
      :telemetry.detach({[:mv_opentelemetry_harness, :repo], MvOpentelemetry.Ecto, :handle_event})
  end

  test "puts stacktrace when enabled" do
    MvOpentelemetry.Ecto.register_tracer(
      tracer_id: :test_ecto_tracer,
      span_prefix: [:mv_opentelemetry_harness, :repo],
      default_attributes: [{"service.component", "test.harness"}]
    )

    config =
      :mv_opentelemetry_harness
      |> Application.get_env(MvOpentelemetryHarness.Repo)
      |> then(&([stacktrace: true] ++ &1))

    Repo.with_dynamic_repo(config, fn ->
      Page.all() |> Repo.all()
      assert_receive {:span, span(name: "mv_opentelemetry_harness.repo.pages") = span_record}
      assert {:attributes, _, _, _, attributes} = span(span_record, :attributes)
      assert %{"ecto.stacktrace" => stacktrace} = attributes
      assert is_binary(stacktrace)
    end)

    assert :ok ==
             :telemetry.detach(
               {[:mv_opentelemetry_harness, :repo], MvOpentelemetry.Ecto, :handle_event}
             )
  end

  test "raises when span_prefix is not given" do
    assert_raise MvOpentelemetry.Error, "span_prefix is required", fn ->
      MvOpentelemetry.Ecto.register_tracer([])
    end

    {:error, :not_found} =
      :telemetry.detach({[:mv_opentelemetry_harness, :repo], MvOpentelemetry.Ecto, :handle_event})
  end
end
