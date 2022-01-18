defmodule MvOpentelemetry.FilteringSampler do
  @moduledoc """
  EXPERIMENTAL Filtering sampler for OpenTelemetry spans.

  This sampler can be used to filter out spans based on their names. Accepts both a list of
  strings and a list of regular expressions as `filter_list` map key and `default` key which
  represents the sampler to use for non-filtered sampling decisions.

  How to use configuration:

  ```
  config :opentelemetry,
    sampler:
      {MvOpentelemetry.FilteringSampler,
        %{
          filter_list: [~r/phoenix.live_view.handle_[a-z_\.]+/],
          default: {:parent_based, %{root: {:trace_id_ratio_based, 1.0}}}
        }}
  ```
  """

  @behaviour :otel_sampler

  @impl true
  @spec description(:otel_sampler.sampler_config()) :: :otel_sampler.description()
  def description(policies) do
    "Policies based sampler: #{inspect(policies)}"
  end

  @impl true
  @spec setup(%{
          filter_list: [String.t() | Regex.t()],
          default: {module(), :otel_sampler.sampler_opts()}
        }) :: %{
          filter_list: [String.t() | Regex.t()],
          default: :otel_sampler.t()
        }
  def setup(%{filter_list: filter_list, default: {sampler, opts}}) do
    default = :otel_sampler.new({sampler, opts})
    %{filter_list: filter_list, default: default}
  end

  @impl true
  @spec should_sample(
          :otel_ctx.t(),
          :opentelemetry.trace_id(),
          :otel_links.t(),
          :opentelemetry.span_name(),
          :opentelemetry.span_kind(),
          :opentelemetry.attributes_map(),
          :otel_sampler.sampler_config()
        ) :: :otel_sampler.sampling_result()
  def should_sample(
        ctx,
        traceid,
        links,
        span_name,
        kind,
        attributes,
        %{
          filter_list: filter_list,
          default: default
        }
      ) do
    is_filtered? = Enum.any?(filter_list, fn filter -> String.match?(span_name, filter) end)

    if is_filtered? do
      span_ctx = :otel_tracer.current_span_ctx(ctx)
      {:record_only, [], :otel_span.tracestate(span_ctx)}
    else
      {default_sampler, _desc, default_config} = default

      default_sampler.should_sample(
        ctx,
        traceid,
        links,
        span_name,
        kind,
        attributes,
        default_config
      )
    end
  end
end
