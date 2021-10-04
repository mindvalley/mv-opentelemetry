defmodule MvOpentelemetryHarness.Pet do
  @derive Jason.Encoder
  defstruct [:name]

  @type t :: %__MODULE__{name: String.t()}
end
