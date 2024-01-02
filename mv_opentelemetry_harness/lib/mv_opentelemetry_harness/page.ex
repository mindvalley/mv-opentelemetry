defmodule MvOpentelemetryHarness.Page do
  use Ecto.Schema
  import Ecto.Query, only: [from: 2]
  alias Ecto.Changeset

  schema "pages" do
    field(:uuid, :binary_id, read_after_writes: true)
    field(:title, :string)
    field(:body, :string)

    timestamps(type: :utc_datetime)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> Changeset.cast(attrs, [:title, :body])
    |> Changeset.validate_required([:title, :body])
  end

  def all do
    from p in __MODULE__, select: p
  end
end
