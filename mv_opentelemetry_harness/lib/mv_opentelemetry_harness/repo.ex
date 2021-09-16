defmodule MvOpentelemetryHarness.Repo do
  use Ecto.Repo,
    otp_app: :mv_opentelemetry_harness,
    adapter: Ecto.Adapters.Postgres
end
