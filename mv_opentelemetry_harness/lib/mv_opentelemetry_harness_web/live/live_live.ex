defmodule MvOpentelemetryHarnessWeb.LiveLive do
  use MvOpentelemetryHarnessWeb, :live_view

  alias MvOpentelemetryHarness.Page
  alias MvOpentelemetryHarness.Repo
  import Ecto.Query, only: [from: 2]

  @impl true
  def mount(_params, _session, socket) do
    query = from p in Page, select: p
    pages = Repo.all(query)

    socket = assign(socket, :pages, pages)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
