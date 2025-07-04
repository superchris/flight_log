defmodule FlightLog.Flights.Flight do
  use Ecto.Schema
  import Ecto.Changeset

  schema "flights" do
    field :hobbs_reading, :decimal
    field :flight_date, :date
    field :pilot_id, :id
    field :airplane_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(flight, attrs) do
    flight
    |> cast(attrs, [:hobbs_reading, :flight_date])
    |> validate_required([:hobbs_reading, :flight_date])
  end
end
