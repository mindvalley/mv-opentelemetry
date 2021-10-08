defmodule MvOpentelemetryHarness.Human do
  alias MvOpentelemetryHarness.Pet

  defstruct [:id, :name, :pets]
  @type t() :: %__MODULE__{id: String.t(), name: String.t(), pets: [Pet.t()]}
end
