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
    pilot = pilot_fixture()

    {:ok, airplane} =
      attrs
      |> Enum.into(%{
        initial_hobbs_reading: "120.5",
        make: "some make",
        model: "some model",
        tail_number: "some tail_number",
        year: 42,
        pilot_id: pilot.id
      })
      |> FlightLog.Airplanes.create_airplane()

    airplane
  end
end
