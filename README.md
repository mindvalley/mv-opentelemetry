# MvOpentelemetry

[![Static Application Security Testing](https://github.com/mindvalley/mv-opentelemetry/actions/workflows/gh-action-sast-ci.yaml/badge.svg)](https://github.com/mindvalley/mv-opentelemetry/actions/workflows/gh-action-sast-ci.yaml)

OpenTelemetry instrumentation, as used in Mindvalley.

Used to publish Opentelemetry events to applicable processors, for example
to Honeycomb.

Opentelemetry resources and processor are configured outside of the scope
of this module, use Opentelemetry directly.

## Example usage

Somewhere in your application startup, for example in Application.start/2:

```elixir
def start(_type, _args) do
  :ok = MvOpentelemetry.register_tracer(:ecto, span_prefix: [:my_app, :repo])
  :ok = MvOpentelemetry.register_tracer(:ecto, span_prefix: [:my_app, :replica_repo])
  :ok = MvOpentelemetry.register_tracer(:cowboy)
  :ok = MvOpentelemetry.register_tracer(:plug, adapter: cowboy)
  :ok = MvOpentelemetry.register_tracer(:live_view)
  :ok = MvOpentelemetry.register_tracer(:absinthe)
  :ok = MvOpentelemetry.register_tracer(:dataloader)
end
```

## Installation

The package can be installed by adding `mv_opentelemetry` to your list of
dependencies in `mix.exs`. In this example, we'll use `opentelemetry_exporter`
which can send data to any OTLP enabled collector.

```elixir
def deps do
  [
    {:mv_opentelemetry, github: "mindvalley/mv-opentelemetry", tag: "v3.0.0"},
    {:opentelemetry_exporter, "~> 1.0.0"},
  ]
end
```

And then configure your processor:

```elixir
# config/runtime.ex
use Config

config :opentelemetry,
  processors: [
    otel_batch_processor: %{
      exporter:
        {:opentelemetry_exporter,
         %{
           endpoints: [{:https, 'api.honeycomb.io', 443, '/v1/traces'}],
           headers: [
             {"x-honeycomb-team", "REPLACE_ME"},
             {"x-honeycomb-dataset", "REPLACE_ME"}
           ]
         }}
    }
  ]
```

Then you need to add opentelemetry to the list of extra applications running in your system:
```
# mix.exs
def application do
  [
    mod: {MyApp.Application, []},
    extra_applications: [
      :opentelemetry_exporter,
      :opentelemetry
    ]
  ]
end
# or in release section
releases: [
  my_instrumented_release: [
    applications: [opentelemetry_exporter: :permanent, opentelemetry: :temporary]
  ]

```
## Contributing

When you want to open a PR to this repository, ensure that you sign the Certificate of origin:

```
$ git commit -s -m "Amazing new feature"
```

[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fmindvalley%2Fmv-opentelemetry.svg?type=large)](https://app.fossa.com/projects/git%2Bgithub.com%2Fmindvalley%2Fmv-opentelemetry?ref=badge_large)
