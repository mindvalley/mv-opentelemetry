defmodule MvOpentelemetryHarnessWeb.PageController do
  use MvOpentelemetryHarnessWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
