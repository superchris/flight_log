defmodule FlightLog.FlightsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FlightLog.Flights` context.
  """

  import FlightLog.AccountsFixtures
  import FlightLog.AirplanesFixtures

  @doc """
  Generate a flight.
  """
  def flight_fixture(attrs \\ %{}) do
    pilot = pilot_fixture()
    airplane = airplane_fixture()

    # Extract inserted_at if provided, as it needs special handling
    {inserted_at, attrs} = Map.pop(attrs, :inserted_at)

    {:ok, flight} =
      attrs
      |> Enum.into(%{
        flight_date: ~D[2025-07-03],
        hobbs_reading: "120.5",
        pilot_id: pilot.id,
        airplane_id: airplane.id
      })
      |> FlightLog.Flights.create_flight()

    # If inserted_at was provided, update the record with it
    case inserted_at do
      nil -> flight
      datetime ->
        FlightLog.Repo.update_all(
          FlightLog.Flights.Flight,
          [set: [inserted_at: datetime]],
          [where: [id: flight.id]]
        )
        %{flight | inserted_at: datetime}
    end
  end
end
