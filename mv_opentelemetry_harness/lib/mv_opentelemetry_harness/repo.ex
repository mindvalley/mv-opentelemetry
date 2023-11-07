defmodule MvOpentelemetryHarness.Repo do
  use Ecto.Repo,
    otp_app: :mv_opentelemetry_harness,
    adapter: Ecto.Adapters.Postgres

  def with_dynamic_repo(credentials, callback) do
    default_dynamic_repo = get_dynamic_repo()
    start_opts = [name: nil, pool_size: 1] ++ credentials
    {:ok, repo} = __MODULE__.start_link(start_opts)

    try do
      __MODULE__.put_dynamic_repo(repo)
      callback.()
    after
      __MODULE__.put_dynamic_repo(default_dynamic_repo)
      Supervisor.stop(repo)
    end
  end
end
