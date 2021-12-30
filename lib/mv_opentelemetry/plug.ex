defmodule MvOpentelemetry.Plug do
  @moduledoc false

  alias OpenTelemetry.Span

  @tracer_id __MODULE__

  @spec register_tracer(opts :: Access.t()) :: :ok
  def register_tracer(opts) do
    opts = handle_opts(opts)
    prefix = opts[:span_prefix]
    tracer_id = opts[:tracer_id]

    :ok =
      :telemetry.attach(
        {tracer_id, __MODULE__, :handle_start_event},
        prefix ++ [:start],
        &__MODULE__.handle_start_event/4,
        opts
      )

    :ok =
      :telemetry.attach(
        {tracer_id, __MODULE__, :handle_stop_event},
        prefix ++ [:stop],
        &__MODULE__.handle_stop_event/4,
        opts
      )
  end

  defp handle_opts(opts) do
    span_prefix = opts[:span_prefix] || [:phoenix, :endpoint]
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

  @spec handle_start_event(_ :: any(), _ :: any(), %{conn: Plug.Conn.t()}, Access.t()) :: :ok
  def handle_start_event(_, _, %{conn: conn} = meta, opts) do
    :otel_propagator_text_map.extract(conn.req_headers)

    request_id = :proplists.get_value("x-request-id", conn.resp_headers, "")
    user_agent = :proplists.get_value("user-agent", conn.req_headers, "")
    referer = :proplists.get_value("referer", conn.req_headers, "")
    client_ip = client_ip(conn)

    attributes = [
      {"http.client_ip", client_ip},
      {"http.host", conn.host},
      {"http.method", conn.method},
      {"http.scheme", "#{conn.scheme}"},
      {"http.request_path", conn.request_path},
      {"http.request_id", request_id},
      {"http.user_agent", user_agent},
      {"http.referer", referer}
    ]

    query_attributes = Enum.map(conn.query_params, &prefix_key_with(&1, "http.query_params"))
    path_attributes = Enum.map(conn.path_params, &prefix_key_with(&1, "http.path_params"))

    attributes = attributes ++ query_attributes ++ path_attributes

    event_name = (opts[:name_prefix] ++ [String.downcase(conn.method)]) |> Enum.join(".")

    OpentelemetryTelemetry.start_telemetry_span(opts[:tracer_id], event_name, meta, %{})
    |> Span.set_attributes(attributes)

    :ok
  end

  @spec handle_stop_event(_ :: any(), _ :: any(), %{conn: Plug.Conn.t()}, Access.t()) :: :ok
  def handle_stop_event(_, _, %{conn: conn} = meta, opts) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)
    Span.set_attribute(ctx, "http.status", conn.status)

    if conn.status >= 400 do
      Span.set_status(ctx, OpenTelemetry.status(:error, ""))
      Span.set_attributes(ctx, error: true)
    end

    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
  end

  defp prefix_key_with({key, value}, prefix) when is_binary(key) do
    complete_key = prefix <> "." <> key
    {complete_key, value}
  end

  defp client_ip(conn) do
    forwarded_for = :proplists.get_value("x-forwarded-for", conn.req_headers, nil)

    if forwarded_for do
      String.split(forwarded_for, ",")
      |> Enum.map(&String.trim/1)
      |> List.first()
    else
      to_string(:inet.ntoa(conn.remote_ip))
    end
  end
end
