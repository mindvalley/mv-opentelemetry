defmodule MvOpentelemetry.MixProject do
  use Mix.Project

  def project do
    [
      app: :mv_opentelemetry,
      version: "1.14.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: :covertool],
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        ignore_warnings: ".known_dialyzer_warnings",
        flags: [:underspecs]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: extra_applications(Mix.env())
    ]
  end

  defp extra_applications(:test) do
    [:logger, :runtime_tools, :opentelemetry_exporter, :opentelemetry, :mv_opentelemetry_harness]
  end

  defp extra_applications(:dev) do
    [:logger, :runtime_tools, :opentelemetry_exporter, :opentelemetry, :mv_opentelemetry_harness]
  end

  defp extra_applications(_), do: [:logger, :runtime_tools]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # OpenTelemetry
      {:opentelemetry_telemetry, "~> 1.0"},
      {:opentelemetry_api, "~> 1.0"},
      {:opentelemetry_process_propagator, "~> 0.1"},
      {:opentelemetry_semantic_conventions, "~> 0.1"},

      # Test and development harness
      {:opentelemetry, "~> 1.0", only: [:dev, :test]},
      {:opentelemetry_exporter, "~> 1.0", only: [:dev, :test]},
      {:mv_opentelemetry_harness, path: "./mv_opentelemetry_harness", only: [:dev, :test]},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:plug, "~> 1.0", optional: true},
      {:phoenix_live_view, "~> 0.16", optional: true},
      {:absinthe, "~> 1.0", optional: true},
      {:floki, ">= 0.30.0", only: :test},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:bypass, "~> 2.1", only: [:test]},
      {:covertool, "~> 2.0", only: [:test]}
    ]
  end

  defp aliases do
    [
      test: [
        "ecto.create --repo MvOpentelemetryHarness.Repo --quiet",
        "ecto.migrate --repo MvOpentelemetryHarness.Repo --quiet",
        "test"
      ]
    ]
  end
end
