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
      airplane = airplane_fixture(%{tail_number: "N99999", initial_hobbs_reading: Decimal.new("120.0")})

      _flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("123.5")
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      assert html =~ "Flight Hours: 3.5 hours"  # 123.5 - 120.0
    end

        test "calculates flight hours correctly for multiple flights", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N88888", initial_hobbs_reading: Decimal.new("95.0")})

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

      # First flight should show 5.0 hours (100.0 - 95.0 initial hobbs reading)
      assert html =~ "Flight Hours: 5.0 hours"
      # Second flight should show 2.5 hours (102.5 - 100.0)
      assert html =~ "Flight Hours: 2.5 hours"
      # Third flight should show 1.7 hours (104.2 - 102.5)
      assert html =~ "Flight Hours: 1.7 hours"
    end

        test "handles flights with same date correctly", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N77777", initial_hobbs_reading: Decimal.new("48.0")})

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

      # First flight (chronologically) should show 2.0 hours (50.0 - 48.0 initial)
      assert html =~ "Flight Hours: 2.0 hours"
      # Second flight should show 1.3 hours (51.3 - 50.0)
      assert html =~ "Flight Hours: 1.3 hours"
    end

    test "displays total flight hours for multiple flights", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N66666", initial_hobbs_reading: Decimal.new("75.0")})

      # Create multiple flights with different flight hours
      _flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("78.5"),  # 3.5 hours
        inserted_at: ~U[2024-01-10 10:00:00Z]
      })

      _flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("80.2"),  # 1.7 hours
        inserted_at: ~U[2024-01-15 10:00:00Z]
      })

      _flight3 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        hobbs_reading: Decimal.new("82.0"),  # 1.8 hours
        inserted_at: ~U[2024-01-20 10:00:00Z]
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # Should show total flight hours (3.5 + 1.7 + 1.8 = 7.0)
      assert html =~ "Total Hours:"
      assert html =~ "7.0 hours"
      refute html =~ "Total Hobbs Time:"
    end

    test "displays correct total flight hours for single flight", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N55555", initial_hobbs_reading: Decimal.new("25.0")})

      _flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("27.3")  # 2.3 hours
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      assert html =~ "Total Hours:"
      assert html =~ "2.3 hours"
    end

    test "shows zero total hours when no flights exist", %{conn: conn} do
      airplane = airplane_fixture(%{tail_number: "N44444"})

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      assert html =~ "No flights"
      refute html =~ "Total Hours:"  # Should not show total when no flights
    end
  end
end
