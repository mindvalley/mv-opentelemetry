use Mix.Config

config :mv_opentelemetry_harness,
  ecto_repos: [MvOpentelemetryHarness.Repo]

# Configures the endpoint
config :mv_opentelemetry_harness, MvOpentelemetryHarnessWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "yu69b2fyPQLDba6EWwyNe2xAXAkcAQT68owg8KhGL/Hfosl3QuYOffSE+eFvqeuX",
  live_view: [signing_salt: "FqZ8F1CaCmC4SQIB"],
  render_errors: [
    view: MvOpentelemetryHarnessWeb.ErrorView,
    accepts: ~w(html json),
    layout: false
  ],
  pubsub_server: MvOpentelemetryHarness.PubSub,
  live_view: [signing_salt: "n4EZeui4"],
  http: [port: 4002],
  server: false

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :opentelemetry, processors: [otel_batch_processor: %{scheduled_delay_ms: 1}]

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :mv_opentelemetry_harness, MvOpentelemetryHarness.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_ROOT_PASSWORD") || System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: "mv_opentelemetry_harness_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# Print only warnings and errors during test
config :logger, level: :warn
config :phoenix, :json_library, Jason
