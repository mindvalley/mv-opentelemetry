# MvOpentelemetry

OpenTelemetry instrumentation, as used in Mindvalley.

Used to publish Opentelemetry events to applicable processors, for example
to Honeycomb.

Opentelemetry resources and processor are configured outside of the scope
of this module, use Opentelemetry directly.

## Example usage

Somewhere in your application startup, for example in Application.start/2:

```elixir
def start(_type, _args) do
  :ok = MvOpentelemetry.register_application(:my_app)
  :ok = MvOpentelemetry.register_tracer(:ecto, span_prefix: [:my_app, :repo])

  :ok =
    MvOpentelemetry.register_tracer(:ecto,
      span_prefix: [:my_app, :replica_repo],
      tracer_id: :replica
    )

  :ok = MvOpentelemetry.register_tracer(:plug)
  :ok = MvOpentelemetry.register_tracer(:live_view)
  :ok = MvOpentelemetry.register_tracer(:absinthe)
end
```

### Note about Absinthe tracers

In case your application uses Absinthe to implement GraphQL and you return structs from your
resolvers, ensure that each of the structs implements the Jason.Encoder protocol.

## Installation

The package can be installed by adding `mv_opentelemetry` to your list of
dependencies in `mix.exs`. In this example, we'll use `opentelemetry_honeycomb`
as the processor.

```elixir
def deps do
  [
    {:mv_opentelemetry, git: "git@github.com:mindvalley/mv-opentelemetry.git"},
    {:opentelemetry_honeycomb, "~> 0.5.0-rc.1"}
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
        {OpenTelemetry.Honeycomb.Exporter, write_key: "REPLACE_ME", dataset: "REPLACE_ME"}
    }
  ]
```

## Contributing

When you want to open a PR to this repository, ensure that you sign the Certificate of origin:

```
$ git commit -s -m "Amazing new feature"
```

[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fmindvalley%2Fmv-opentelemetry.svg?type=large)](https://app.fossa.com/projects/git%2Bgithub.com%2Fmindvalley%2Fmv-opentelemetry?ref=badge_large)
