defmodule MvOpentelemetry.Ecto do
  @moduledoc false

  require OpenTelemetry.Tracer
  alias OpenTelemetry.Span
  alias OpenTelemetry.Tracer

  @tracer_id __MODULE__

  @time_attributes [:decode_time, :query_time, :queue_time]

  @spec register_tracer(Access.t()) :: :ok | {:error, :already_exists}
  def register_tracer(opts) do
    opts = handle_opts(opts)
    prefix = opts[:span_prefix]

    :telemetry.attach(
      {prefix, __MODULE__, :handle_event},
      prefix ++ [:query],
      &__MODULE__.handle_event/4,
      opts
    )
  end

  defp handle_opts(opts) do
    span_prefix =
      opts[:span_prefix] ||
        raise MvOpentelemetry.Error, message: "span_prefix is required", module: __MODULE__

    name_prefix = opts[:name_prefix] || span_prefix
    tracer_id = opts[:tracer_id] || @tracer_id
    tracer_version = opts[:tracer_version] || MvOpentelemetry.version()

    [
      span_prefix: span_prefix,
      name_prefix: name_prefix,
      tracer_id: tracer_id,
      tracer_version: tracer_version
    ]
  end

  @spec handle_event([atom()], map(), map(), Access.t()) :: :ok
  def handle_event(event, measurements, meta, config) do
    %{query: query, source: source, result: query_result, repo: repo, type: type} = meta
    total_time = measurements.total_time
    end_time = :opentelemetry.timestamp()
    start_time = end_time - total_time
    repo_config = repo.config()

    url =
      case repo_config[:url] do
        nil -> URI.to_string(%URI{scheme: "ecto", host: repo_config[:hostname]})
        url -> url
      end

    db_type =
      case type do
        :ecto_sql_query -> :sql
        _ -> type
      end

    result =
      case query_result do
        {:ok, _} -> []
        _ -> [error: true]
      end

    base_attributes = [
      {"db.type", db_type},
      {"db.statement", query},
      {"db.source", source},
      {"db.instance", repo_config[:database]},
      {"db.url", url},
      {"db.total_time_microseconds", convert_time(total_time)}
    ]

    all_attributes = result ++ base_attributes ++ time_attributes(measurements)

    span_name = name(config, event, source)
    span_opts = %{start_time: start_time, attributes: all_attributes}

    Tracer.start_span(span_name, span_opts)
    |> Span.end_span()

    :ok
  end

  defp name(config, event, source) do
    prefix = config[:name_prefix] || event

    complete_name =
      case source do
        nil -> prefix
        some -> prefix ++ [some]
      end

    Enum.join(complete_name, ".")
  end

  defp time_attributes(measurements) do
    measurements
    |> Enum.into(%{})
    |> Map.take(@time_attributes)
    |> Enum.reject(fn {_, value} -> is_nil(value) end)
    |> Enum.map(fn {k, v} -> {time_key(k), convert_time(v)} end)
  end

  defp time_key(atom) when atom in @time_attributes do
    String.to_atom("db.#{atom}_microseconds")
  end

  defp convert_time(time), do: System.convert_time_unit(time, :native, :microsecond)
end
