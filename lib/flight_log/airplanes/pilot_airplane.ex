defmodule FlightLog.Airplanes.PilotAirplane do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "pilots_airplanes" do
    belongs_to :pilot, FlightLog.Accounts.Pilot
    belongs_to :airplane, FlightLog.Airplanes.Airplane

    timestamps(type: :utc_datetime)
  end

  def changeset(pilot_airplane, attrs) do
    pilot_airplane
    |> cast(attrs, [:pilot_id, :airplane_id])
    |> validate_required([:pilot_id, :airplane_id])
    |> unique_constraint([:pilot_id, :airplane_id])
  end
end
