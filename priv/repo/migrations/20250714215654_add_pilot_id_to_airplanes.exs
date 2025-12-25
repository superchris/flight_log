defmodule FlightLog.Repo.Migrations.AddPilotIdToAirplanes do
  use Ecto.Migration

  def change do
    alter table(:airplanes) do
      add :pilot_id, references(:pilots, on_delete: :delete_all), null: true
    end

    create index(:airplanes, [:pilot_id])
  end
end
