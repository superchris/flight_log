defmodule FlightLog.CostsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FlightLog.Costs` context.
  """

  import FlightLog.AirplanesFixtures

  @doc """
  Generate a cost.
  """
  def cost_fixture(attrs \\ %{}) do
    airplane = attrs[:airplane] || airplane_fixture()

    {:ok, cost} =
      attrs
      |> Enum.into(%{
        airplane_id: airplane.id,
        cost_type: :monthly,
        amount: "500.00",
        description: "Test cost"
      })
      |> Map.drop([:airplane])
      |> FlightLog.Costs.create_cost()

    cost
  end

  @doc """
  Generate a monthly cost.
  """
  def monthly_cost_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    cost_fixture(Map.merge(attrs, %{cost_type: :monthly, amount: "1200.00", description: "Monthly insurance"}))
  end

  @doc """
  Generate an hourly cost.
  """
  def hourly_cost_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    cost_fixture(Map.merge(attrs, %{cost_type: :hourly, amount: "125.50", description: "Hourly fuel cost"}))
  end

  @doc """
  Generate a one-time cost.
  """
  def one_time_cost_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    cost_fixture(Map.merge(attrs, %{cost_type: :one_time, amount: "50000.00", description: "Purchase price"}))
  end
end
