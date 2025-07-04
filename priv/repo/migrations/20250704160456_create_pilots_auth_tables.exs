defmodule FlightLog.Repo.Migrations.CreatePilotsAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:pilots) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pilots, [:email])

    create table(:pilots_tokens) do
      add :pilot_id, references(:pilots, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:pilots_tokens, [:pilot_id])
    create unique_index(:pilots_tokens, [:context, :token])
  end
end
