defmodule MvOpentelemetryHarnessWeb.Schema do
  use Absinthe.Schema

  alias MvOpentelemetryHarness.Pet
  alias MvOpentelemetryHarness.Human

  # Example data
  @items %{
    "foo" => %Human{id: "foo", name: "Stephen"},
    "bar" => %Human{id: "bar", name: "Bar"}
  }

  object :pet do
    field :name, :string
  end

  object :human do
    field :id, :string
    field :name, :string

    field :pets, list_of(:pet) do
      resolve(&__MODULE__.pet_resolver/2)
    end
  end

  def human_resolver(%{id: item_id}, _) do
    {:ok, @items[item_id]}
  end

  def pet_resolver(_map, _opts) do
    {:ok, [%Pet{name: "Pinky"}, %Pet{name: "Brain"}]}
  end

  query do
    field :human, :human do
      arg(:id, non_null(:id))
      resolve(&__MODULE__.human_resolver/2)
    end
  end
end
