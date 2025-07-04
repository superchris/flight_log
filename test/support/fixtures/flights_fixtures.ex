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

    {:ok, flight} =
      attrs
      |> Enum.into(%{
        flight_date: ~D[2025-07-03],
        hobbs_reading: "120.5",
        pilot_id: pilot.id,
        airplane_id: airplane.id
      })
      |> FlightLog.Flights.create_flight()

    flight
  end
end
