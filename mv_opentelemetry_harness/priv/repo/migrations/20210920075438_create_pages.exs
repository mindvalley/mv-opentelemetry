defmodule MvOpentelemetryHarness.Repo.Migrations.CreatePages do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", "DROP EXTENSION \"uuid-ossp\"")

    create table("pages") do
      add(:title, :string, null: false)
      add(:body, :text, null: false)
      add(:uuid, :binary_id, null: false, default: fragment("uuid_generate_v4()"))

      timestamps()
    end

    create(index("pages", [:title], unique: true))
    create(index("pages", [:uuid], unique: true))
  end
end
