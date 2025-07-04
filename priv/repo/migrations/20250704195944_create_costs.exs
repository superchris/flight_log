defmodule FlightLog.Repo.Migrations.CreateCosts do
  use Ecto.Migration

  def change do
    create table(:costs) do
      add :airplane_id, references(:airplanes, on_delete: :delete_all), null: false
      add :cost_type, :string, null: false
      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :description, :string

      timestamps(type: :utc_datetime)
    end

    create index(:costs, [:airplane_id])
    create constraint(:costs, :valid_cost_type, check: "cost_type IN ('monthly', 'hourly', 'one_time')")
  end
end
