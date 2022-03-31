defmodule MvOpentelemetry.Plug do
  @moduledoc false

  alias OpenTelemetry.Span

  @spec register_tracer(opts :: Access.t()) :: :ok
  def register_tracer(opts) do
    opts = handle_opts(opts)
    prefix = opts[:span_prefix]

    :ok =
      :telemetry.attach(
        {prefix, __MODULE__, :handle_start_event},
        prefix ++ [:start],
        &__MODULE__.handle_start_event/4,
        opts
      )

    :ok =
      :telemetry.attach(
        {prefix, __MODULE__, :handle_stop_event},
        prefix ++ [:stop],
        &__MODULE__.handle_stop_event/4,
        opts
      )
  end

  defp handle_opts(opts) do
    span_prefix = opts[:span_prefix] || [:phoenix, :endpoint]
    tracer_id = :mv_opentelemetry
    query_params_whitelist = opts[:query_params_whitelist]
    default_attributes = opts[:default_attributes] || []

    [
      span_prefix: span_prefix,
      tracer_id: tracer_id,
      query_params_whitelist: query_params_whitelist,
      default_attributes: default_attributes
    ]
  end

  @spec handle_start_event(_ :: any(), _ :: any(), %{conn: Plug.Conn.t()}, Access.t()) :: :ok
  def handle_start_event(_, _, %{conn: conn} = meta, opts) do
    :otel_propagator_text_map.extract(conn.req_headers)

    request_id = :proplists.get_value("x-request-id", conn.resp_headers, "")
    user_agent = :proplists.get_value("user-agent", conn.req_headers, "")
    force_trace = :proplists.get_value("x-force-trace", conn.req_headers, false)

    force_trace_attrs =
      if force_trace == "true" do
        [{"force_trace", true}]
      else
        []
      end

    peer_data =
      if function_exported?(Plug.Conn, :get_peer_data, 1) do
        Plug.Conn.get_peer_data(conn)
      else
        %{}
      end

    peer_ip = Map.get(peer_data, :address)
    referer = :proplists.get_value("referer", conn.req_headers, "")
    client_ip = client_ip(conn)

    attributes = [
      {"http.client_ip", client_ip},
      {"http.host", conn.host},
      {"http.method", conn.method},
      {"http.scheme", "#{conn.scheme}"},
      {"http.target", conn.request_path},
      {"http.request_id", request_id},
      {"http.user_agent", user_agent},
      {"http.referer", referer},
      {"http.flavor", http_flavor(conn.adapter)},
      {"net.host.ip", to_string(:inet_parse.ntoa(conn.remote_ip))},
      {"net.host.port", conn.port},
      {"net.peer.ip", to_string(:inet_parse.ntoa(peer_ip))},
      {"net.peer.port", peer_data.port},
      {"net.transport", "IP.TCP"}
    ]

    query_attributes =
      conn.query_params
      |> filter_list(opts[:query_params_whitelist])
      |> Enum.map(&prefix_key_with(&1, "http.query_params"))

    path_attributes = Enum.map(conn.path_params, &prefix_key_with(&1, "http.path_params"))

    attributes =
      attributes ++
        force_trace_attrs ++ query_attributes ++ path_attributes ++ opts[:default_attributes]

    event_name = "HTTP #{conn.method}"

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

  defp filter_list(params, nil), do: params

  defp filter_list(params, whitelist) do
    Enum.filter(params, fn {k, _v} -> Enum.member?(whitelist, k) end)
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

  defp http_flavor({_adapter_name, meta}) do
    case Map.get(meta, :version) do
      :"HTTP/1.0" -> "1.0"
      :"HTTP/1.1" -> "1.1"
      :"HTTP/2.0" -> "2.0"
      :"HTTP/2" -> "2.0"
      :SPDY -> "SPDY"
      :QUIC -> "QUIC"
      nil -> ""
    end
  end
end
