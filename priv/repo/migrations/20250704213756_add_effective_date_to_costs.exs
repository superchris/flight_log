defmodule FlightLog.Repo.Migrations.AddEffectiveDateToCosts do
  use Ecto.Migration

  def change do
    alter table(:costs) do
      add :effective_date, :date
    end
  end
end
