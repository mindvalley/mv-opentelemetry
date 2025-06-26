defmodule MvOpentelemetry.Bandit do
  @moduledoc false

  @spec register_tracer(opts :: Access.t()) :: :ok
  def register_tracer(opts) do
    default_opts = %{
      public_endpoint: false,
      request_headers: ["referer"],
      response_headers: ["x-request-id"]
    }

    opts = Enum.into(opts, %{})
    opts = Map.merge(default_opts, opts)

    :ok = OpentelemetryBandit.setup(opts)
  end
end
