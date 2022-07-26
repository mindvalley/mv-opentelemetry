# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mv_opentelemetry_harness,
  ecto_repos: [MvOpentelemetryHarness.Repo]

# Configures the endpoint
config :mv_opentelemetry_harness, MvOpentelemetryHarnessWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "yu69b2fyPQLDba6EWwyNe2xAXAkcAQT68owg8KhGL/Hfosl3QuYOffSE+eFvqeuX",
  render_errors: [view: MvOpentelemetryHarnessWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: MvOpentelemetryHarness.PubSub,
  live_view: [signing_salt: "n4EZeui4"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
