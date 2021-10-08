defmodule MvOpentelemetry.DerivedStruct do
  @moduledoc false
  @derive MvOpentelemetry.Sanitizer
  defstruct [:id, :name, :email]
end

defmodule MvOpentelemetry.ExceptStruct do
  @moduledoc false
  @derive {MvOpentelemetry.Sanitizer, except: [:email]}
  defstruct [:id, :name, :email]
end

defmodule MvOpentelemetry.OnlyStruct do
  @moduledoc false
  @derive {MvOpentelemetry.Sanitizer, only: [:email]}
  defstruct [:id, :name, :email]
end

defmodule MvOpentelemetry.DerivedViaProtocolStruct do
  @moduledoc false
  defstruct [:id, :name, :email]
end

defmodule MvOpentelemetry.NotImplementedStruct do
  @moduledoc false
  defstruct [:id, :name, :email]
end

require Protocol

Protocol.derive(MvOpentelemetry.Sanitizer, MvOpentelemetryHarness.Pet)
Protocol.derive(MvOpentelemetry.Sanitizer, MvOpentelemetry.DerivedViaProtocolStruct)

defimpl MvOpentelemetry.Sanitizer, for: MvOpentelemetryHarness.Human do
  def sanitize(value, _opts) do
    %{
      id: MvOpentelemetry.sanitize!(value.id),
      name: MvOpentelemetry.sanitize!(value.name),
      pets: MvOpentelemetry.sanitize!(value.pets)
    }
  end
end
