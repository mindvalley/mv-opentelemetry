defmodule MvOpentelemetry.SpanTracer do
  @moduledoc """
  Reusable behaviour for listening to events emmited with `:telemetry.span/3` convention and
  converting them into OpenTelemetry traces.

  You can define custom tracers modules and then register them at the start of your application.
  You are required to implement at least `c:handle_event/4` callback, which has exactly the same
  type signature as BEAM telemetry handlers.

  ## Example

  ```
  defmodule MyApp.SpanTracer do
    use MvOpentelemetry.SpanTracer,
      events: [[:my_event, :start], [:my_event, :stop], [:my_event, :exception]]

    def handle_event([:my_event, :start], measurements, meta, opts) do
      event_name = opts[:prefix]
      attributes = ["my_event.name": meta.name]

      OpentelemetryTelemetry.start_telemetry_span(opts[:name], event_name, meta, %{})
      |> Span.set_attributes(attributes)

      :ok
    end

    def handle_event([:my_event, :stop], measurements, meta, opts) do
      ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:name], meta)
      OpentelemetryTelemetry.end_telemetry_span(opts[:name], meta)
      :ok
    end

    def handle_event([:my_event, :exception], measurements, meta, opts) do
      ctx = OpentelemetryTelemetry.set_current_telemetry_span(opts[:name], meta)
      attributes = [reason: meta.reason, error: true, stacktrace: meta.stacktrace, kind: meta.kind]

      OpenTelemetry.Span.set_attributes(ctx, attributes)
      OpentelemetryTelemetry.end_telemetry_span(opts[:name], meta)

      :ok
    end
  end

  def MyApp do
    def start(_type, _args) do
      MyApp.SpanTracer.register_tracer()
    end
  end
  ```

  In the example above, the `c:register_tracer/1` is generated automatically, and when called it
  will register the telemetry handler under `{MyApp.SpanTracer, MyApp.SpanTracer}`. The following
  options will be merged with options provided to `c:register_tracer/1` and forwarded to
  `c:handle_event/4` callback as config (4th argument).

  ```
  [version: "0.1.0", prefix: MyApp.SpanTracer, name: MyApp.SpanTracer]
  ```

  If you want to, you can also completely override the `c:register_tracer/1` callback.

  ## Required parameters

  * `:events` - a list of telemetry events you want the span to attach to.

  ## Optional Parameters

  * `:name` - atom to register the handler with. Defaults to module name, but can be changed if
  needed.
  * `:prefix` - atom or string that can be used generate span name. Defaults to current module
  name.
  * `version` - string to version the tracer within OpenTelemetry. Defaults to "0.1.0"

  All optional parameters can be also provided in `c:register_tracer/1` call site:

  ```
  def MyApp do
    def start(_type, _args) do
      MyApp.SpanTracer.register_tracer(name: :test_span, version: "0.2.0", prefix: "other_tracer")
    end
  end
  ```
  """

  @callback handle_event(
              event :: [atom()],
              measurements :: map(),
              meta :: map(),
              opts :: Access.t()
            ) :: :ok

  @callback register_tracer(opts :: Access.t()) :: :ok | {:error, :already_exists}

  defmacro __using__(opts) do
    events = Access.fetch!(opts, :events)
    name = Access.get(opts, :name, __CALLER__.module)
    prefix = Access.get(opts, :prefix, name)
    tracer_version = Access.get(opts, :version, MvOpentelemetry.version())

    quote location: :keep do
      @behaviour MvOpentelemetry.SpanTracer

      require OpenTelemetry.Tracer
      require OpenTelemetry.Span

      alias OpenTelemetry.Span

      @spec register_tracer(Access.t()) :: :ok | {:error, :already_exists}
      def register_tracer(opts \\ []) do
        prefix = Access.get(opts, :prefix, unquote(prefix))
        name = Access.get(opts, :name, unquote(name))
        version = Access.get(opts, :version, unquote(tracer_version))

        opts_with_defaults = merge_defaults(opts, prefix: prefix, name: name, version: version)

        :opentelemetry.register_tracer(name, version)

        :telemetry.attach_many(
          {name, __MODULE__},
          unquote(events),
          &__MODULE__.handle_event/4,
          opts_with_defaults
        )
      end

      defp merge_defaults(opts, defaults) do
        opts
        |> merge_default(:name, defaults[:name])
        |> merge_default(:prefix, defaults[:prefix])
        |> merge_default(:version, defaults[:version])
      end

      def merge_default(opts, key, new_value) do
        {_, new_container} =
          Access.get_and_update(opts, key, fn
            nil -> {nil, new_value}
            some -> {some, some}
          end)

        new_container
      end

      defoverridable register_tracer: 1
    end
  end
end
