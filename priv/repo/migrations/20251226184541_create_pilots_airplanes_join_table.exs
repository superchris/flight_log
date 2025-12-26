defmodule FlightLog.Repo.Migrations.CreatePilotsAirplanesJoinTable do
  use Ecto.Migration

  def change do
    create table(:pilots_airplanes, primary_key: false) do
      add :pilot_id, references(:pilots, on_delete: :delete_all), null: false
      add :airplane_id, references(:airplanes, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:pilots_airplanes, [:pilot_id])
    create index(:pilots_airplanes, [:airplane_id])
    create unique_index(:pilots_airplanes, [:pilot_id, :airplane_id])

    # Migrate existing data from airplanes.pilot_id to join table
    execute(
      "INSERT INTO pilots_airplanes (pilot_id, airplane_id, inserted_at, updated_at) SELECT pilot_id, id, NOW(), NOW() FROM airplanes WHERE pilot_id IS NOT NULL",
      "UPDATE airplanes SET pilot_id = (SELECT pilot_id FROM pilots_airplanes WHERE airplane_id = airplanes.id LIMIT 1)"
    )

    # Remove the old pilot_id column from airplanes
    alter table(:airplanes) do
      remove :pilot_id, references(:pilots, on_delete: :delete_all)
    end
  end
end
