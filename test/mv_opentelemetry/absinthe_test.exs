defmodule MvOpentelemetry.AbsintheTest do
  use MvOpentelemetry.OpenTelemetryCase

  test "sends otel events to pid", %{conn: conn} do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())
    MvOpentelemetry.Absinthe.register_tracer(tracer_id: :test_absinthe_tracer)

    query = """
    query{
      human(id: "foo"){
        name
        id,
        pets{
          name
        }
      }
    }
    """

    conn = post(conn, "/graphql", %{"query" => query})

    assert json_response(conn, 200) == %{
             "data" => %{
               "human" => %{
                 "id" => "foo",
                 "name" => "Stephen",
                 "pets" => [%{"name" => "Pinky"}, %{"name" => "Brain"}]
               }
             }
           }

    assert_receive {:span, span_record}
    assert "absinthe.resolve.field" == span(span_record, :name)
    attributes = span(span_record, :attributes)

    assert {:"graphql.field.name", "human"} in attributes
    assert {:"graphql.field.schema", MvOpentelemetryHarnessWeb.Schema} in attributes
    assert {:"graphql.field.arguments", %{id: "foo"}} in attributes

    assert_receive {:span, span_record}
    assert "absinthe.resolve.field" == span(span_record, :name)
    attributes = span(span_record, :attributes)

    assert {:"graphql.field.name", "pets"} in attributes
    assert {:"graphql.field.schema", MvOpentelemetryHarnessWeb.Schema} in attributes
    assert {:"graphql.field.arguments", %{}} in attributes

    :ok = :telemetry.detach({:test_absinthe_tracer, MvOpentelemetry.Absinthe, :handle_stop_event})

    :ok =
      :telemetry.detach({:test_absinthe_tracer, MvOpentelemetry.Absinthe, :handle_start_event})
  end

  test "sends error data to pid", %{conn: conn} do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())
    MvOpentelemetry.Absinthe.register_tracer(tracer_id: :test_absinthe_error_tracer)

    # Here be error
    query = """
    query{
      human(id: 1.22){
        name
        id,
        pets{
          name
        }
      }
    }
    """

    conn = post(conn, "/graphql", %{"query" => query})

    assert json_response(conn, 200) == %{
             "errors" => [
               %{
                 "locations" => [%{"column" => 9, "line" => 2}],
                 "message" => "Argument \"id\" has invalid value 1.22."
               }
             ]
           }

    assert_receive {:span, span_record}
    assert "absinthe.execute.operation" == span(span_record, :name)
    attributes = span(span_record, :attributes)

    assert {:"graphql.operation.input", query} in attributes
    assert {:"graphql.operation.schema", MvOpentelemetryHarnessWeb.Schema} in attributes

    :ok =
      :telemetry.detach(
        {:test_absinthe_error_tracer, MvOpentelemetry.Absinthe, :handle_stop_event}
      )

    :ok =
      :telemetry.detach(
        {:test_absinthe_error_tracer, MvOpentelemetry.Absinthe, :handle_start_event}
      )
  end
end
