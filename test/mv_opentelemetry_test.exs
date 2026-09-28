defmodule MvOpentelemetryTest do
  use ExUnit.Case, async: true

  test "version/0 reports the released version" do
    assert MvOpentelemetry.version() == "3.6.0"
  end
end
