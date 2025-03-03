defmodule MvOpentelemetry.Finch do
  @moduledoc false

  use MvOpentelemetry.SpanTracer,
    name: :finch,
    events: [
      [:finch, :request, :start],
      [:finch, :request, :stop],
      [:finch, :request, :exception]
    ]

  alias OpenTelemetry.SemConv

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
      {SemConv.HTTPAttributes.http_request_method(), method},
      {SemConv.URLAttributes.url_scheme(), scheme},
      {SemConv.ServerAttributes.server_address(), host},
      {SemConv.ServerAttributes.server_port(), port},
      {SemConv.URLAttributes.url_path(), path},
      {SemConv.URLAttributes.url_full(), build_url(scheme, host, port, path)},
      {SemConv.OtelAttributes.otel_scope_name(), :mv_opentelemetry},
      {SemConv.OtelAttributes.otel_scope_version(), MvOpentelemetry.version()}
    ]

    attributes = opts[:default_attributes] ++ finch_attributes
    span_name = "#{method}"

    OpentelemetryTelemetry.start_telemetry_span(opts[:tracer_id], span_name, meta, %{
      attributes: attributes,
      kind: :client
    })

    :ok
  end

  def handle_event([:finch, :request, :stop], _measurements, meta, opts) do
    %{result: result} = meta

    content_length = get_content_length(result)
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)
    Span.set_attributes(ctx, content_length)
    status = get_status(result)
    error = get_error(result)

    if status do
      Span.set_attributes(ctx, %{SemConv.HTTPAttributes.http_response_status_code() => status})
    end

    if error do
      error_status = OpenTelemetry.status(:error, error)
      Span.set_status(ctx, error_status)
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
    case result do
      {:ok, %{headers: headers}} ->
        :otel_http.extract_headers_attributes(:response, headers, ["content-length"])

      _ ->
        %{}
    end
  end

  defp build_url(:https, host, 443, path), do: "https://#{host}#{path}"
  defp build_url(:http, host, 80, path), do: "http://#{host}#{path}"
  defp build_url(scheme, host, port, path), do: "#{scheme}://#{host}:#{port}#{path}"
end
