defmodule MvOpentelemetry.DataloaderTest do
  use MvOpentelemetry.OpenTelemetryCase

  import Ecto.Query

  setup do
    source = Dataloader.Ecto.new(MvOpentelemetryHarness.Repo, query: &query/2)
    pet_source = Dataloader.KV.new(&query/2)

    dataloader =
      Dataloader.new()
      |> Dataloader.add_source(MvOpentelemetryHarness.Repo, source)
      |> Dataloader.add_source(MvOpentelemetryHarness.Pet, pet_source)

    %{dataloader: dataloader}
  end

  test "sends batch events", %{dataloader: loader} do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())

    MvOpentelemetry.Dataloader.register_tracer(
      name: :test_dataloader_tracer,
      default_attributes: [{"service.component", "test.harness"}]
    )

    page = %MvOpentelemetryHarness.Page{title: "page", body: "page"}
    _page = MvOpentelemetryHarness.Repo.insert!(page)

    second_page = %MvOpentelemetryHarness.Page{title: "second_page", body: "second_page"}
    _second_page = MvOpentelemetryHarness.Repo.insert!(second_page)

    pages = MvOpentelemetryHarness.Repo.all(MvOpentelemetryHarness.Page)
    page_ids = Enum.map(pages, & &1.id)

    loader
    |> Dataloader.load_many(MvOpentelemetryHarness.Repo, MvOpentelemetryHarness.Page, page_ids)
    |> Dataloader.run()

    assert_receive {:span, span_record}
    assert "dataloader.source.batch.run" == span(span_record, :name)
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    assert attributes == %{"service.component" => "test.harness"}

    :ok = :telemetry.detach({:test_dataloader_tracer, MvOpentelemetry.Dataloader})
  end

  test "sends source events", %{dataloader: loader} do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())

    MvOpentelemetry.Dataloader.register_tracer(
      name: :test_dataloader_tracer,
      default_attributes: [{"service.component", "test.harness"}]
    )

    loader
    |> Dataloader.load_many(MvOpentelemetryHarness.Pet, MvOpentelemetryHarness.Pet, [1])
    |> Dataloader.run()

    assert_receive {:span, span_record}
    assert "dataloader.source.run" == span(span_record, :name)
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)
    assert attributes == %{"service.component" => "test.harness"}

    :ok = :telemetry.detach({:test_dataloader_tracer, MvOpentelemetry.Dataloader})
  end

  def query(MvOpentelemetryHarness.Page, _params) do
    MvOpentelemetryHarness.Page |> order_by(desc: :id)
  end

  def query(MvOpentelemetryHarness.Pet, _params) do
    %{
      %{} => [
        %MvOpentelemetryHarness.Pet{id: 1, name: "Pinky"},
        %MvOpentelemetryHarness.Pet{id: 2, name: "Brain"}
      ]
    }
  end
end
