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
      env: %{
        method: method,
        url: url_string
      }
    } = meta

    %{scheme: scheme, host: host, port: port, path: path} = URI.parse(url_string)

    method = String.upcase(Atom.to_string(method))

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
    %{
      env: %{
        body: body,
        status: status
      }
    } = meta

    error = get_error(body)
    content_length = get_content_length(body)

    ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:tracer_id], meta)

    if status do
      Span.set_attributes(ctx, %{Trace.http_status_code() => status})
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

  defp attach_context(:undefined), do: :ok
  defp attach_context(context), do: OpenTelemetry.Ctx.attach(context)

  defp detach_context(:undefined), do: :ok
  defp detach_context(context), do: OpenTelemetry.Ctx.detach(context)

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
end
