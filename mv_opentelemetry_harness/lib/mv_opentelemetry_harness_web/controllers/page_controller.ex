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
end
