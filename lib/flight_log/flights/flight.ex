defmodule FlightLog.Flights.Flight do
  use Ecto.Schema
  import Ecto.Changeset

  schema "flights" do
    field :hobbs_reading, :decimal
    field :flight_date, :date

    belongs_to :pilot, FlightLog.Accounts.Pilot
    belongs_to :airplane, FlightLog.Airplanes.Airplane

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(flight, attrs) do
    flight
    |> cast(attrs, [:hobbs_reading, :flight_date, :pilot_id, :airplane_id])
    |> validate_required([:hobbs_reading, :flight_date, :pilot_id, :airplane_id])
  end
end
