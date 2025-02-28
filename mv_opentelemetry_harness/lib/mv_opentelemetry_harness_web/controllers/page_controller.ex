defmodule MvOpentelemetryHarnessWeb.PageController do
  use MvOpentelemetryHarnessWeb, :controller
  alias MvOpentelemetryHarness.Page
  alias MvOpentelemetryHarness.Repo
  import Ecto.Query, only: [from: 2]

  def index(conn, _params) do
    query = from p in Page, select: p
    pages = Repo.all(query)

    render(conn, "index.html", pages: pages)
  end

  def show(%{path_info: ["timeout"]} = conn, _params) do
    :timer.sleep(1000)
    query = from p in Page, select: p
    pages = Repo.all(query)

    render(conn, "index.html", pages: pages)
  end

  def show(%{path_info: ["500"]}, _params) do
    raise "500"
  end
end
