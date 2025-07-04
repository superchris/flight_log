defmodule FlightLog.FlightsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FlightLog.Flights` context.
  """

  @doc """
  Generate a flight.
  """
  def flight_fixture(attrs \\ %{}) do
    {:ok, flight} =
      attrs
      |> Enum.into(%{
        flight_date: ~D[2025-07-03],
        hobbs_reading: "120.5"
      })
      |> FlightLog.Flights.create_flight()

    flight
  end
end
