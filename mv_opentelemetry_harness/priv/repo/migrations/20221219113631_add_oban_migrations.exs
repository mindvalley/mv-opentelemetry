defmodule MvOpentelemetryHarness.Repo.Migrations.AddObanMigrations do
  use Ecto.Migration

  def up, do: Oban.Migrations.up()
  def down, do: Oban.Migrations.down()
end
