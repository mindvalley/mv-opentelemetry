defmodule MvOpentelemetry.Tesla do
  @moduledoc false

  use MvOpentelemetry.SpanTracer,
    name: :tesla,
    events: [
      [:tesla, :request, :start],
      [:tesla, :request, :stop],
      [:tesla, :request, :exception]
    ]

  require OpenTelemetry.SemanticConventions.Trace, as: Trace

  def handle_event([:tesla, :request, :start], _measurements, meta, opts) do
    %{
      env: %Tesla.Env{
        method: method,
        url: url_string
      }
    } = meta

    %{scheme: scheme, host: host, port: port, path: path} = URI.parse(url_string)

    tesla_attributes = [
      {Trace.http_method(), method},
      {Trace.http_scheme(), scheme},
      {:"http.host", host},
      {Trace.net_peer_name(), host},
      {Trace.net_peer_port(), port},
      {Trace.http_target(), path},
      {Trace.http_url(), url_string}
    ]

    attributes = opts[:default_attributes] ++ tesla_attributes
    span_name = "HTTP #{method}"

    OpentelemetryTelemetry.start_telemetry_span(opts[:tracer_id], span_name, meta, %{
      attributes: attributes,
      kind: :client
    })

    :ok
  end

  def handle_event([:tesla, :request, :stop], _measurements, meta, opts) do
    %{
      env: %Tesla.Env{
        body: body,
        status: status
      }
    } = meta

    error = get_error(body)
    content_length = get_content_length(body)

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
end
