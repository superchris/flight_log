defmodule FlightLog.Repo.Migrations.AddNameFieldsToPilots do
  use Ecto.Migration

  def change do
    alter table(:pilots) do
      add :first_name, :string
      add :last_name, :string
    end
  end
end
