defmodule MvOpentelemetryHarnessWeb.Router do
  use MvOpentelemetryHarnessWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :telemetry do
    plug Plug.Telemetry, event_prefix: [:harness, :request]
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/" do
    pipe_through :api
    pipe_through :telemetry

    forward "/graphql", Absinthe.Plug,
      schema: MvOpentelemetryHarnessWeb.Schema,
      analyze_complexity: true

    forward "/graphiql", Absinthe.Plug.GraphiQL, schema: MvOpentelemetryHarnessWeb.Schema
  end

  scope "/", MvOpentelemetryHarnessWeb do
    pipe_through [:browser, :telemetry]

    live "/live", LiveLive
    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", MvOpentelemetryHarnessWeb do
  #   pipe_through :api
  # end
end
