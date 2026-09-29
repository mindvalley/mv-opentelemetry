defmodule MvOpentelemetryTest do
  use ExUnit.Case, async: true

  test "version/0 matches the version declared in mix.exs" do
    assert MvOpentelemetry.version() == Mix.Project.config()[:version]
  end
end
