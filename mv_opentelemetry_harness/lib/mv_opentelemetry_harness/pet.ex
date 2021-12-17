defmodule MvOpentelemetryHarness.Pet do
  defstruct [:name, :id]

  @type t :: %__MODULE__{name: String.t(), id: integer()}
end
