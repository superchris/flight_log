defmodule FlightLog.Airplanes.Airplane do
  use Ecto.Schema
  import Ecto.Changeset

  schema "airplanes" do
    field :year, :integer
    field :make, :string
    field :tail_number, :string
    field :initial_hobbs_reading, :decimal
    field :model, :string

    belongs_to :pilot, FlightLog.Accounts.Pilot
    has_many :flights, FlightLog.Flights.Flight
    has_many :costs, FlightLog.Costs.Cost

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(airplane, attrs) do
    airplane
    |> cast(attrs, [:tail_number, :initial_hobbs_reading, :model, :make, :year, :pilot_id])
    |> validate_required([:tail_number, :initial_hobbs_reading, :model, :make, :year])
    |> foreign_key_constraint(:pilot_id)
  end
end
