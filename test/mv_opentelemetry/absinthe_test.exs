defmodule MvOpentelemetry.AbsintheTest do
  use MvOpentelemetry.OpenTelemetryCase

  test "sends field events when asked for it", %{conn: conn} do
    MvOpentelemetry.Absinthe.register_tracer(
      name: :test_absinthe_tracer,
      default_attributes: [{"service.component", "test.harness"}],
      include_field_resolution: true
    )

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

    assert_receive {:span, span(name: "graphql.resolve.field.human") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"graphql.field.name", "human"} in attributes
    assert {"service.component", "test.harness"} in attributes
    assert {"graphql.field.schema", MvOpentelemetryHarnessWeb.Schema} in attributes

    assert_receive {:span, span(name: "graphql.resolve.field.pets") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"graphql.field.name", "pets"} in attributes
    assert {"service.component", "test.harness"} in attributes
    assert {"graphql.field.schema", MvOpentelemetryHarnessWeb.Schema} in attributes

    :ok = :telemetry.detach({:test_absinthe_tracer, MvOpentelemetry.Absinthe})
  end

  test "sends only top-level events", %{conn: conn} do
    MvOpentelemetry.Absinthe.register_tracer(name: :test_absinthe_tracer)

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

    assert_receive {:span, span(name: "graphql.execute.operation") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"graphql.operation.input", query} in attributes
    assert {"graphql.operation.schema", MvOpentelemetryHarnessWeb.Schema} in attributes

    :ok = :telemetry.detach({:test_absinthe_tracer, MvOpentelemetry.Absinthe})
  end

  test "sends error data to pid", %{conn: conn} do
    MvOpentelemetry.Absinthe.register_tracer(name: :test_absinthe_error_tracer)

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

    assert_receive {:span, span(name: "graphql.execute.operation") = span_record}
    {:attributes, _, _, _, attributes} = span(span_record, :attributes)

    assert {"graphql.operation.input", query} in attributes
    assert {"graphql.operation.schema", MvOpentelemetryHarnessWeb.Schema} in attributes

    :ok = :telemetry.detach({:test_absinthe_error_tracer, MvOpentelemetry.Absinthe})
  end
end
