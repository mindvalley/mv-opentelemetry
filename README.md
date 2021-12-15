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
  :ok = MvOpentelemetry.register_tracer(:ecto, span_prefix: [:my_app, :repo])

  :ok =
    MvOpentelemetry.register_tracer(:ecto,
      span_prefix: [:my_app, :replica_repo],
      tracer_id: :replica
    )

  :ok = MvOpentelemetry.register_tracer(:plug)
  :ok = MvOpentelemetry.register_tracer(:live_view)
  :ok = MvOpentelemetry.register_tracer(:absinthe)
  :ok = MvOpentelemetry.register_tracer(:dataloader)
end
```

### Data Sanitization - MvOpentelemetry.Sanitizer

The library contains a protocol to sanitize telemetry data to remove sensitive information
and transform it to format that can be encoded to JSON. After being passed through
this protocol, data should have the following characteristics:

  * it is safe to store in tracing software, does not contain sensitive
    or personally identifiable data.
  * it can be later converted to JSON, which is standard storage format for
    most tracing data. Structs become bare maps.

You are required to use it when you send custom structs to your tracing software.

##### Using the `@derive` annotation

The notations below are equivalent. You can also skip the options completely.

```elixir
defmodule MyApp.User do
  @derive {MvOpentelemetry.Sanitizer, [only: [:id, :email]]}
  @derive {MvOpentelemetry.Sanitizer, [except: [:password]]}
  defstruct [:id, :email, :password]
end
```

#### Implementing the protocol directly

If you want to perform more complex transformations, implement the sanitize function directly.

```elixir
defimpl MvOpentelemetry.Sanitizer, for: MyApp.User do
  def sanitize(user, _opts) do
    %{id: user.id, email: Base.encode64(user.email)}
  end
end
```

## Installation

The package can be installed by adding `mv_opentelemetry` to your list of
dependencies in `mix.exs`. In this example, we'll use `opentelemetry_exporter`
which can send data to any OTLP enabled collector.

```elixir
def deps do
  [
    {:mv_opentelemetry, git: "git@github.com:mindvalley/mv-opentelemetry.git"},
    {:opentelemetry_exporter, "~> 1.0.0-rc.3"},
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

## Contributing

When you want to open a PR to this repository, ensure that you sign the Certificate of origin:

```
$ git commit -s -m "Amazing new feature"
```

[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fmindvalley%2Fmv-opentelemetry.svg?type=large)](https://app.fossa.com/projects/git%2Bgithub.com%2Fmindvalley%2Fmv-opentelemetry?ref=badge_large)
