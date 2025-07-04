defmodule FlightLog.Repo.Migrations.AddNotesToFlights do
  use Ecto.Migration

  def change do
    alter table(:flights) do
      add :notes, :text
    end
  end
end
