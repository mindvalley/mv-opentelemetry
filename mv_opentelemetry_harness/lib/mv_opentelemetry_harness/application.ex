defmodule MvOpentelemetryHarness.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      MvOpentelemetryHarness.Repo,
      # Start the Telemetry supervisor
      MvOpentelemetryHarnessWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: MvOpentelemetryHarness.PubSub},
      # Start the Endpoint (http/https)
      MvOpentelemetryHarnessWeb.Endpoint,
      # Start a worker by calling: MvOpentelemetryHarness.Worker.start_link(arg)
      # {MvOpentelemetryHarness.Worker, arg}

      {Oban, repo: MvOpentelemetryHarness.Repo, plugins: [Oban.Plugins.Pruner]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MvOpentelemetryHarness.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    MvOpentelemetryHarnessWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
