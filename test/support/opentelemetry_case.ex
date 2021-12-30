defmodule MvOpentelemetry.OpenTelemetryCase do
  @moduledoc """
  Basic opentelemetry test case.
  """

  alias Ecto.Adapters.SQL.Sandbox
  alias MvOpentelemetryHarness.Repo
  use ExUnit.CaseTemplate

  using do
    quote do
      import MvOpentelemetry.OpenTelemetryCase
      import Plug.Conn
      import Phoenix.ConnTest

      alias MvOpentelemetryHarnessWeb.Router, as: Routes

      @endpoint MvOpentelemetryHarnessWeb.Endpoint

      require Record
      @span Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl")
      Record.defrecordp(:span, @span)
    end
  end

  setup tags do
    :ok = Sandbox.checkout(Repo)

    unless tags[:async] do
      Sandbox.mode(Repo, {:shared, self()})
    end

    conn = Phoenix.ConnTest.build_conn()

    {:ok, conn: conn}
  end
end
