defmodule MvOpentelemetry.Cowboy do
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

    :ok = :opentelemetry_cowboy.setup(opts)
  end
end
