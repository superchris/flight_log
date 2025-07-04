defmodule FlightLog.AirplanesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FlightLog.Airplanes` context.
  """

  @doc """
  Generate a airplane.
  """
  def airplane_fixture(attrs \\ %{}) do
    {:ok, airplane} =
      attrs
      |> Enum.into(%{
        initial_hobbs_reading: "120.5",
        make: "some make",
        model: "some model",
        tail_number: "some tail_number",
        year: 42
      })
      |> FlightLog.Airplanes.create_airplane()

    airplane
  end
end
