defmodule FlightLogWeb.FlightLive.MonthlyTest do
  use FlightLogWeb.ConnCase

  import Phoenix.LiveViewTest
  import FlightLog.AirplanesFixtures
  import FlightLog.FlightsFixtures

    describe "Monthly Flights" do
    setup :register_and_log_in_pilot

    test "lists flights for current pilot, airplane, and month", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture()
      flight_date = ~D[2024-01-15]

      # Create a flight for this pilot and airplane in January 2024
      _flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: flight_date,
        hobbs_reading: Decimal.new("10.5")
      })

      # Create a flight in a different month (should not appear)
      _other_flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-02-15],
        hobbs_reading: Decimal.new("5.2")
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.id}?year=2024&month=1")

      assert html =~ "Flights for #{airplane.tail_number}"
      assert html =~ "January 2024"
      assert html =~ "10.5"
      refute html =~ "5.2"  # February flight should not appear
    end

    test "shows empty state when no flights exist", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.id}?year=2024&month=1")

      assert html =~ "No flights"
      assert html =~ "January 2024"
    end

    test "navigates between months", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, index_live, _html} =
        live(conn, ~p"/flights/monthly/#{airplane.id}?year=2024&month=1")

      # Test next month navigation
      index_live
      |> element("button", "Next Month")
      |> render_click()

      assert_patch(index_live, ~p"/flights/monthly/#{airplane.id}?year=2024&month=2")

      # Test previous month navigation
      index_live
      |> element("button", "Previous Month")
      |> render_click()

      assert_patch(index_live, ~p"/flights/monthly/#{airplane.id}?year=2024&month=1")
    end

    test "redirects when airplane not found", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/airplanes"}}} =
        live(conn, ~p"/flights/monthly/999")
    end
  end
end
