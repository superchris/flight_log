defmodule FlightLog.Repo.Migrations.CreateAirplanes do
  use Ecto.Migration

  def change do
    create table(:airplanes) do
      add :tail_number, :string
      add :initial_hobbs_reading, :decimal
      add :model, :string
      add :make, :string
      add :year, :integer

      timestamps(type: :utc_datetime)
    end
  end
end
