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

    test "displays costs when costs exist", %{conn: conn, pilot: pilot} do
      import FlightLog.CostsFixtures

      airplane = airplane_fixture(%{tail_number: "N12345", initial_hobbs_reading: Decimal.new("100.0")})

      # Create flights for January 2024
      _flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("102.0")  # 2.0 hours
      })

            # Create costs
      _monthly_cost = cost_fixture(%{airplane: airplane, cost_type: :monthly, amount: "500.00",
                                   description: "Insurance", effective_date: ~D[2024-01-01]})
      _hourly_cost = cost_fixture(%{airplane: airplane, cost_type: :hourly, amount: "125.00",
                                  description: "Fuel", effective_date: ~D[2024-01-01]})
      _one_time_cost = cost_fixture(%{airplane: airplane, cost_type: :one_time, amount: "2000.00",
                                    description: "Maintenance", effective_date: ~D[2024-01-10]})

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # Should show costs section
      assert html =~ "Monthly Costs for January 2024"

      # Should show monthly costs
      assert html =~ "Monthly Costs"
      assert html =~ "Insurance"
      assert html =~ "$500.00"

      # Should show hourly costs
      assert html =~ "Hourly Costs"
      assert html =~ "Fuel"
      assert html =~ "$125.00/hr × 2.0 hrs"
      assert html =~ "$250.00"

      # Should show one-time costs
      assert html =~ "One-time Costs"
      assert html =~ "Maintenance"
      assert html =~ "$2000.00"

      # Should show total cost (500 + 250 + 2000 = 2750)
      assert html =~ "Total Monthly Cost:"
      assert html =~ "$2750.00"
    end

    test "displays no costs message when no costs exist", %{conn: conn} do
      airplane = airplane_fixture(%{tail_number: "N99999"})

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      assert html =~ "Monthly Costs for January 2024"
      assert html =~ "No costs recorded for this month"
    end

    test "updates costs when navigating between months", %{conn: conn, pilot: pilot} do
      import FlightLog.CostsFixtures

      airplane = airplane_fixture(%{tail_number: "N11111", initial_hobbs_reading: Decimal.new("50.0")})

      # Create flight in January
      _flight_jan = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("52.0")  # 2.0 hours
      })

      # Create flight in February
      _flight_feb = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-02-15],
        hobbs_reading: Decimal.new("53.0")  # 1.0 hours
      })

            # Create costs
      _monthly_cost = cost_fixture(%{airplane: airplane, cost_type: :monthly, amount: "600.00",
                                   description: "Insurance", effective_date: ~D[2024-01-01]})
      _hourly_cost = cost_fixture(%{airplane: airplane, cost_type: :hourly, amount: "100.00",
                                  description: "Fuel", effective_date: ~D[2024-01-01]})
      _one_time_cost_jan = cost_fixture(%{airplane: airplane, cost_type: :one_time, amount: "1500.00",
                                        description: "January Maintenance", effective_date: ~D[2024-01-10]})
      _one_time_cost_feb = cost_fixture(%{airplane: airplane, cost_type: :one_time, amount: "800.00",
                                        description: "February Maintenance", effective_date: ~D[2024-02-05]})

      {:ok, index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # January costs: 600 (monthly) + 200 (hourly: 100*2) + 1500 (one-time) = 2300
      assert html =~ "Monthly Costs for January 2024"
      assert html =~ "January Maintenance"
      assert html =~ "$2300.00"
      refute html =~ "February Maintenance"

      # Navigate to February
      index_live
      |> element("button", "Next Month")
      |> render_click()

      html = render(index_live)

      # February costs: 600 (monthly) + 300 (hourly: 100*3) + 800 (one-time) = 1700
      assert html =~ "Monthly Costs for February 2024"
      assert html =~ "February Maintenance"
      assert html =~ "$1700.00"
      refute html =~ "January Maintenance"
    end

    test "handles zero flight hours with hourly costs", %{conn: conn} do
      import FlightLog.CostsFixtures

      airplane = airplane_fixture(%{tail_number: "N22222"})

            # Create hourly cost but no flights
      _hourly_cost = cost_fixture(%{airplane: airplane, cost_type: :hourly, amount: "150.00",
                                  description: "Fuel", effective_date: ~D[2024-01-01]})

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # Should not show hourly costs section when no flight hours
      refute html =~ "Hourly Costs"
      assert html =~ "No costs recorded for this month"
    end

    test "handles costs with nil effective date", %{conn: conn, pilot: pilot} do
      import FlightLog.CostsFixtures

      airplane = airplane_fixture(%{tail_number: "N33333", initial_hobbs_reading: Decimal.new("75.0")})

      # Create flight
      _flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("76.5")  # 1.5 hours
      })

            # Create costs with nil effective date
      _monthly_cost = cost_fixture(%{airplane: airplane, cost_type: :monthly, amount: "400.00",
                                   description: "Insurance", effective_date: nil})
      _hourly_cost = cost_fixture(%{airplane: airplane, cost_type: :hourly, amount: "80.00",
                                  description: "Fuel", effective_date: nil})

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # Should show costs even with nil effective date
      assert html =~ "Insurance"
      assert html =~ "$400.00"
      assert html =~ "Fuel"
      assert html =~ "$80.00/hr × 1.5 hrs"
      assert html =~ "$120.00"

      # Total: 400 + 120 = 520
      assert html =~ "$520.00"
    end

    test "displays costs with proper date formatting", %{conn: conn} do
      import FlightLog.CostsFixtures

      airplane = airplane_fixture(%{tail_number: "N44444"})

            # Create one-time cost with specific date
      _one_time_cost = cost_fixture(%{airplane: airplane, cost_type: :one_time, amount: "1200.00",
                                    description: "Special Maintenance", effective_date: ~D[2024-01-25]})

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # Should show formatted date
      assert html =~ "Special Maintenance"
      assert html =~ "01/25/2024"
      assert html =~ "$1200.00"
    end
  end
end
