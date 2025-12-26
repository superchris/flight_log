defmodule FlightLog.AirplanesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FlightLog.Airplanes` context.
  """

  import FlightLog.AccountsFixtures

  @doc """
  Generate a airplane.
  """
  def airplane_fixture(attrs \\ %{}) do
    pilot = attrs[:pilot] || pilot_fixture()

    {:ok, airplane} =
      attrs
      |> Map.drop([:pilot])
      |> Enum.into(%{
        initial_hobbs_reading: "120.5",
        make: "some make",
        model: "some model",
        tail_number: "some tail_number",
        year: 42
      })
      |> FlightLog.Airplanes.create_airplane()

    {:ok, _airplane} = FlightLog.Airplanes.add_pilot_to_airplane(airplane, pilot)
    # Return fresh airplane without preloaded associations for consistent test comparisons
    FlightLog.Airplanes.get_airplane!(airplane.id)
  end
end
