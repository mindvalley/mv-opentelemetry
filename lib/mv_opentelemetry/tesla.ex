defmodule MvOpentelemetry.Tesla do
  @moduledoc false

  use MvOpentelemetry.SpanTracer,
    name: :tesla,
    events: [
      [:tesla, :request, :start],
      [:tesla, :request, :stop],
      [:tesla, :request, :exception]
    ]

  alias OpenTelemetry.SemConv

  def handle_event([:tesla, :request, :start], _measurements, meta, opts) do
    %{
      env: %{
        method: method,
        url: url_string
      }
    } = meta

    %{scheme: scheme, host: host, port: port, path: path} = URI.parse(url_string)

    method = String.upcase(Atom.to_string(method))

    tesla_attributes = [
      {SemConv.HTTPAttributes.http_request_method(), method},
      {SemConv.URLAttributes.url_scheme(), scheme},
      {SemConv.ServerAttributes.server_address(), host},
      {SemConv.ServerAttributes.server_port(), port},
      {SemConv.URLAttributes.url_path(), path},
      {SemConv.URLAttributes.url_full(), url_string},
      {SemConv.OtelAttributes.otel_scope_name(), :mv_opentelemetry},
      {SemConv.OtelAttributes.otel_scope_version(), MvOpentelemetry.version()}
    ]

    attributes = opts[:default_attributes] ++ tesla_attributes
    span_name = "#{method}"

    parent_context = OpentelemetryProcessPropagator.fetch_parent_ctx(2, :"$callers")
    attach_context(parent_context)

    OpentelemetryTelemetry.start_telemetry_span(opts[:tracer_id], span_name, meta, %{
      attributes: attributes,
      kind: :client
    })

    detach_context(parent_context)
    :ok
  end

  def handle_event([:tesla, :request, :stop], _measurements, meta, opts) do
    %{env: env} = meta
    content_length = get_content_length(env)
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)
    Span.set_attributes(ctx, content_length)
    error = get_error(env.body)

    if env.status do
      Span.set_attributes(ctx, %{SemConv.HTTPAttributes.http_response_status_code() => env.status})
    end

    if error do
      error_status = OpenTelemetry.status(:error, error)
      Span.set_status(ctx, error_status)
    end

    OpentelemetryTelemetry.end_telemetry_span(opts[:tracer_id], meta)
  end

  defp attach_context(:undefined), do: :ok
  defp attach_context(context), do: OpenTelemetry.Ctx.attach(context)

  defp detach_context(:undefined), do: :ok
  defp detach_context(context), do: OpenTelemetry.Ctx.detach(context)

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
end
