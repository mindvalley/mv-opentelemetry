defmodule MvOpentelemetry.Finch do
  @moduledoc false

  use MvOpentelemetry.SpanTracer,
    name: :finch,
    events: [
      [:finch, :request, :start],
      [:finch, :request, :stop],
      [:finch, :request, :exception]
    ]

  alias OpenTelemetry.SemConv.Incubating

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
      {Incubating.HTTPAttributes.http_method(), method},
      {Incubating.HTTPAttributes.http_scheme(), scheme},
      {Incubating.NetworkAttributes.net_peer_name(), host},
      {Incubating.NetworkAttributes.net_peer_port(), port},
      {Incubating.HTTPAttributes.http_target(), path},
      {Incubating.HTTPAttributes.http_url(), build_url(scheme, host, port, path)}
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
      Span.set_attributes(ctx, %{Incubating.HTTPAttributes.http_status_code() => status})
    end

    if error do
      error_status = OpenTelemetry.status(:error, error)
      Span.set_status(ctx, error_status)
    end

    if content_length do
      Span.set_attribute(
        ctx,
        Incubating.HTTPAttributes.http_response_content_length(),
        content_length
      )
    end

    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
  end

  def handle_event(
        [:finch, :request, :exception],
        _measurements,
        %{stacktrace: stacktrace, reason: reason} = meta,
        opts
      ) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)
    Span.record_exception(ctx, reason, stacktrace)
    Span.set_status(ctx, OpenTelemetry.status(:error, ""))
    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
  end

  defp get_status({:ok, response}), do: response.status
  defp get_status(_), do: nil

  defp get_error({:error, %{__exception__: true} = exception}), do: Exception.message(exception)
  defp get_error({:error, reason}), do: inspect(reason)
  defp get_error(_), do: nil

  def get_content_length(result) do
    with {:ok, %{headers: headers}} <- result,
         length <- :proplists.get_value("content-length", headers, ""),
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
