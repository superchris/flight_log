defmodule FlightLogWeb.FlightLive.MonthlyTest do
  use FlightLogWeb.ConnCase

  import Phoenix.LiveViewTest
  import FlightLog.AirplanesFixtures
  import FlightLog.FlightsFixtures

    describe "Monthly Flights" do
    setup :register_and_log_in_pilot

    test "lists flights for all pilots, airplane, and month", %{conn: conn, pilot: pilot} do
      import FlightLog.AccountsFixtures

      airplane = airplane_fixture(%{tail_number: "N12345"})
      other_pilot = pilot_fixture(%{first_name: "Alice", last_name: "Johnson"})
      flight_date = ~D[2024-01-15]

      # Create a flight for this pilot and airplane in January 2024
      _flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: flight_date,
        hobbs_reading: Decimal.new("10.5")
      })

      # Create a flight for another pilot in the same month (should appear)
      _flight2 = flight_fixture(%{
        pilot_id: other_pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        hobbs_reading: Decimal.new("12.0")
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

      assert html =~ "All Flights for #{airplane.tail_number}"
      assert html =~ "January 2024"
      assert html =~ "10.5"  # First pilot's flight
      assert html =~ "12.0"  # Second pilot's flight
      assert html =~ "#{pilot.first_name} #{pilot.last_name}"
      assert html =~ "#{other_pilot.first_name} #{other_pilot.last_name}"
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

    test "previous month from late in the month navigates correctly", %{conn: conn} do
      # Regression test: from December 25, previous month should go to November, not October
      airplane = airplane_fixture(%{tail_number: "N22222"})

      {:ok, index_live, _html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=12")

      # Test previous month navigation from December
      index_live
      |> element("button", "Previous Month")
      |> render_click()

      # Should go to November, not October
      assert_patch(index_live, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=11")
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

      # February flight is 1.0 hours (53.0 - 52.0 from January flight)
      # February costs: 600 (monthly) + 100 (hourly: 100*1) + 800 (one-time) = 1500
      assert html =~ "Monthly Costs for February 2024"
      assert html =~ "February Maintenance"
      assert html =~ "$1500.00"
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

        test "displays pilot summary with flight counts and hours", %{conn: conn, pilot: pilot} do
      import FlightLog.AccountsFixtures

      airplane = airplane_fixture(%{tail_number: "N55555", initial_hobbs_reading: Decimal.new("100.0")})
      other_pilot = pilot_fixture(%{first_name: "Jane", last_name: "Smith"})

      # Create flights for first pilot
      _flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("102.5"),  # 2.5 hours
        inserted_at: ~U[2024-01-10 10:00:00Z]
      })

      _flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("104.0"),  # 1.5 hours
        inserted_at: ~U[2024-01-15 10:00:00Z]
      })

      # Create flight for second pilot
      _flight3 = flight_fixture(%{
        pilot_id: other_pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        hobbs_reading: Decimal.new("106.2"),  # 2.2 hours
        inserted_at: ~U[2024-01-20 10:00:00Z]
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      assert html =~ "Pilot Summary for January 2024"
      assert html =~ "#{pilot.first_name} #{pilot.last_name}"
      assert html =~ "#{other_pilot.first_name} #{other_pilot.last_name}"
      assert html =~ "2 flights • 4.0 hours"  # First pilot: 2.5 + 1.5 = 4.0
      assert html =~ "1 flights • 2.2 hours"  # Second pilot: 2.2
    end

        test "displays pilot cost breakdown when costs exist", %{conn: conn, pilot: pilot} do
      import FlightLog.AccountsFixtures
      import FlightLog.CostsFixtures

      airplane = airplane_fixture(%{tail_number: "N66666", initial_hobbs_reading: Decimal.new("50.0")})
      other_pilot = pilot_fixture(%{first_name: "Bob", last_name: "Wilson"})

      # Create flights
      _flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("52.0"),  # 2.0 hours
        inserted_at: ~U[2024-01-10 10:00:00Z]
      })

      _flight2 = flight_fixture(%{
        pilot_id: other_pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("53.5"),  # 1.5 hours
        inserted_at: ~U[2024-01-15 10:00:00Z]
      })

      # Create costs
      _monthly_cost = cost_fixture(%{airplane: airplane, cost_type: :monthly, amount: "600.00",
                                   description: "Insurance", effective_date: ~D[2024-01-01]})
      _hourly_cost = cost_fixture(%{airplane: airplane, cost_type: :hourly, amount: "100.00",
                                  description: "Fuel", effective_date: ~D[2024-01-01]})
      _one_time_cost = cost_fixture(%{airplane: airplane, cost_type: :one_time, amount: "1000.00",
                                    description: "Maintenance", effective_date: ~D[2024-01-05]})

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # Check pilot cost breakdown appears
      assert html =~ "Pilot Summary for January 2024"
      assert html =~ "#{pilot.first_name} #{pilot.last_name}"
      assert html =~ "#{other_pilot.first_name} #{other_pilot.last_name}"

      # Check cost details for first pilot (2.0 hours)
      # Hourly: 100 * 2.0 = 200, Monthly: 600, One-time: 1000, Total: 1800
      assert html =~ "Hourly costs (2.0 hrs)"
      assert html =~ "$200.00"
      assert html =~ "Monthly costs"
      assert html =~ "$600.00"
      assert html =~ "One-time costs"
      assert html =~ "$1000.00"
      assert html =~ "Total cost"
      assert html =~ "$1800.00"

      # Check cost details for second pilot (1.5 hours)
      # Hourly: 100 * 1.5 = 150, Monthly: 600, One-time: 1000, Total: 1750
      assert html =~ "Hourly costs (1.5 hrs)"
      assert html =~ "$150.00"
      assert html =~ "$1750.00"
    end

    test "does not display pilot summary when no flights exist", %{conn: conn} do
      airplane = airplane_fixture(%{tail_number: "N77777"})

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      refute html =~ "Pilot Summary"
    end

    test "renders log flight modal with form", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N88888", initial_hobbs_reading: Decimal.new("100.0")})
      FlightLog.Airplanes.add_pilot_to_airplane(airplane, pilot)

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # The modal form is rendered in the page (hidden by default)
      assert html =~ "Log Flight - #{airplane.tail_number}"
      assert html =~ "Flying #{airplane.make} #{airplane.model}"
      assert html =~ "Pilot"
      assert html =~ "Hobbs reading"
      assert html =~ "Flight date"
      assert html =~ "id=\"flight-form\""
    end

    test "saves flight from modal and refreshes list", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N89898", initial_hobbs_reading: Decimal.new("100.0")})
      FlightLog.Airplanes.add_pilot_to_airplane(airplane, pilot)

      {:ok, index_live, _html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      {:ok, _new_live, html} =
        index_live
        |> form("#flight-form", flight: %{
          pilot_id: pilot.id,
          hobbs_reading: "105.5",
          flight_date: "2024-01-15"
        })
        |> render_submit()
        |> follow_redirect(conn)

      # After redirect, check the flash and the new flight
      assert html =~ "Flight logged successfully!"
      assert html =~ "105.5"
    end

    test "validates flight form in modal", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N90909", initial_hobbs_reading: Decimal.new("100.0")})
      FlightLog.Airplanes.add_pilot_to_airplane(airplane, pilot)

      {:ok, index_live, _html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      html =
        index_live
        |> form("#flight-form", flight: %{hobbs_reading: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "pilot select defaults to logged in pilot", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N91919", initial_hobbs_reading: Decimal.new("100.0")})
      FlightLog.Airplanes.add_pilot_to_airplane(airplane, pilot)

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # The logged in pilot should be selected by default - check for the option element
      # Phoenix LiveView outputs: selected="selected"
      assert html =~ ~r/<option selected="selected" value="#{pilot.id}">/
    end

    test "pilot select shows all pilots associated with airplane", %{conn: conn, pilot: pilot} do
      import FlightLog.AccountsFixtures

      airplane = airplane_fixture(%{tail_number: "N92929", initial_hobbs_reading: Decimal.new("100.0")})
      other_pilot = pilot_fixture(%{first_name: "Other", last_name: "Pilot"})
      FlightLog.Airplanes.add_pilot_to_airplane(airplane, pilot)
      FlightLog.Airplanes.add_pilot_to_airplane(airplane, other_pilot)

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # Both pilots should appear in the select options
      assert html =~ "#{pilot.first_name} #{pilot.last_name}"
      assert html =~ "#{other_pilot.first_name} #{other_pilot.last_name}"
    end
  end
end
