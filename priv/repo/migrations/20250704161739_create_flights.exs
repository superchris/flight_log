defmodule FlightLog.Repo.Migrations.CreateFlights do
  use Ecto.Migration

  def change do
    create table(:flights) do
      add :hobbs_reading, :decimal
      add :flight_date, :date
      add :pilot_id, references(:pilots, on_delete: :nothing)
      add :airplane_id, references(:airplanes, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:flights, [:pilot_id])
    create index(:flights, [:airplane_id])
  end
end
