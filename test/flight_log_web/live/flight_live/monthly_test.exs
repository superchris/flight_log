defmodule FlightLogWeb.FlightLive.MonthlyTest do
  use FlightLogWeb.ConnCase

  import Phoenix.LiveViewTest
  import FlightLog.AirplanesFixtures
  import FlightLog.FlightsFixtures

    describe "Monthly Flights" do
    setup :register_and_log_in_pilot

    test "lists flights for current pilot, airplane, and month", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N12345"})
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
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      assert html =~ "Flights for #{airplane.tail_number}"
      assert html =~ "January 2024"
      assert html =~ "10.5"
      refute html =~ "5.2"  # February flight should not appear
    end

    test "shows empty state when no flights exist", %{conn: conn} do
      airplane = airplane_fixture(%{tail_number: "N67890"})

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      assert html =~ "No flights"
      assert html =~ "January 2024"
    end

    test "navigates between months", %{conn: conn} do
      airplane = airplane_fixture(%{tail_number: "N11111"})

      {:ok, index_live, _html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # Test next month navigation
      index_live
      |> element("button", "Next Month")
      |> render_click()

      assert_patch(index_live, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=2")

      # Test previous month navigation
      index_live
      |> element("button", "Previous Month")
      |> render_click()

      assert_patch(index_live, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")
    end

    test "redirects when airplane not found", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/airplanes"}}} =
        live(conn, ~p"/flights/monthly/INVALID")
    end

    test "displays flight hours for single flight", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N99999"})

      _flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("10.5")
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      assert html =~ "Flight Hours: 10.5 hours"
    end

    test "calculates flight hours correctly for multiple flights", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N88888"})

      # First flight (chronologically)
      _flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("100.0"),
        inserted_at: ~U[2024-01-10 10:00:00Z]
      })

      # Second flight
      _flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("102.5"),
        inserted_at: ~U[2024-01-15 10:00:00Z]
      })

      # Third flight
      _flight3 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        hobbs_reading: Decimal.new("104.2"),
        inserted_at: ~U[2024-01-20 10:00:00Z]
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # First flight should show 100.0 hours (initial hobbs reading)
      assert html =~ "Flight Hours: 100.0 hours"
      # Second flight should show 2.5 hours (102.5 - 100.0)
      assert html =~ "Flight Hours: 2.5 hours"
      # Third flight should show 1.7 hours (104.2 - 102.5)
      assert html =~ "Flight Hours: 1.7 hours"
    end

    test "handles flights with same date correctly", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N77777"})

      # Two flights on same date, different times
      _flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("50.0"),
        inserted_at: ~U[2024-01-15 09:00:00Z]  # Earlier time
      })

      _flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("51.3"),
        inserted_at: ~U[2024-01-15 14:00:00Z]  # Later time
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # First flight (chronologically) should show 50.0 hours
      assert html =~ "Flight Hours: 50.0 hours"
      # Second flight should show 1.3 hours (51.3 - 50.0)
      assert html =~ "Flight Hours: 1.3 hours"
    end
  end
end
