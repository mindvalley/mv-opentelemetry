defmodule MvOpentelemetry.Finch do
  @moduledoc false

  use MvOpentelemetry.SpanTracer,
    name: :finch,
    events: [
      [:finch, :request, :start],
      [:finch, :request, :stop],
      [:finch, :request, :exception]
    ]

  require OpenTelemetry.SemanticConventions.Trace, as: Trace

  def handle_event([:finch, :request, :start], _measurements, meta, opts) do
    %{
      request: %{
        host: host,
        method: method,
        scheme: scheme,
        port: port,
        path: path
      }
    } = meta

    finch_attributes = [
      {Trace.http_method(), method},
      {Trace.http_scheme(), scheme},
      {:"http.host", host},
      {Trace.net_peer_name(), host},
      {Trace.net_peer_port(), port},
      {Trace.http_target(), path},
      {Trace.http_url(), build_url(scheme, host, port, path)}
    ]

    attributes = opts[:default_attributes] ++ finch_attributes
    span_name = "HTTP #{method}"

    OpentelemetryTelemetry.start_telemetry_span(opts[:tracer_id], span_name, meta, %{
      attributes: attributes,
      kind: :client
    })

    :ok
  end

  def handle_event([:finch, :request, :stop], _measurements, meta, opts) do
    %{result: result} = meta

    status = get_status(result)
    error = get_error(result)
    content_length = get_content_length(result)

    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)

    if status do
      Span.set_attributes(ctx, %{
        # Remove this field after some time in favour of Trace.http_status_code()
        :"http.status" => status,
        Trace.http_status_code() => status
      })
    end

    if error do
      error_status = OpenTelemetry.status(:error, error)
      Span.set_status(ctx, error_status)
    end

    if content_length do
      Span.set_attribute(ctx, Trace.http_response_content_length(), content_length)
    end

    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
  end

  defp get_status({:ok, response}), do: response.status
  defp get_status(_), do: nil

  defp get_error({:error, %{__exception__: true} = exception}), do: Exception.message(exception)
  defp get_error({:error, reason}), do: inspect(reason)
  defp get_error(_), do: nil

  defp get_content_length(result) do
    with {:ok, %{headers: headers}} <- result,
         length <- :proplists.get_value("content-length", headers, :error),
         {int, ""} <- Integer.parse(length) do
      int
    else
      _ -> nil
    end
  end

  defp build_url(:https, host, 443, path), do: "https://#{host}#{path}"
  defp build_url(:http, host, 80, path), do: "http://#{host}#{path}"
  defp build_url(scheme, host, port, path), do: "#{scheme}://#{host}:#{port}#{path}"
end
