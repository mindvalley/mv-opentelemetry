defmodule MvOpentelemetryHarness.Pet do
  defstruct [:name]

  @type t :: %__MODULE__{name: String.t()}
end
