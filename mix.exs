defmodule MvOpentelemetry.MixProject do
  use Mix.Project

  def project do
    [
      app: :mv_opentelemetry,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
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

  defp extra_applications(:test), do: [:logger, :runtime_tools, :mv_opentelemetry_harness]
  defp extra_applications(:dev), do: [:logger, :runtime_tools, :mv_opentelemetry_harness]
  defp extra_applications(_), do: [:logger, :runtime_tools]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # OpenTelemetry
      {:opentelemetry, "~> 0.6.0", override: true},
      {:opentelemetry_api, "~> 0.6.0", override: true},
      {:opentelemetry_telemetry, "~> 1.0.0-beta.2"},

      # JSON
      {:jason, "~> 1.0"},

      # Test and development harness
      {:mv_opentelemetry_harness, path: "./mv_opentelemetry_harness", only: [:dev, :test]},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:floki, ">= 0.30.0", only: :test},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
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
