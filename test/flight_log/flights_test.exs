defmodule FlightLog.FlightsTest do
  use FlightLog.DataCase

  alias FlightLog.Flights

  describe "flights" do
    alias FlightLog.Flights.Flight

    import FlightLog.FlightsFixtures
    import FlightLog.AccountsFixtures
    import FlightLog.AirplanesFixtures

    @invalid_attrs %{hobbs_reading: nil, flight_date: nil, pilot_id: nil, airplane_id: nil}

    test "list_flights/0 returns all flights with preloaded associations" do
      flight = flight_fixture()
      flights = Flights.list_flights()

      assert length(flights) == 1
      [loaded_flight] = flights

      assert loaded_flight.id == flight.id
      assert loaded_flight.flight_date == flight.flight_date
      assert loaded_flight.hobbs_reading == flight.hobbs_reading
      assert Ecto.assoc_loaded?(loaded_flight.pilot)
      assert Ecto.assoc_loaded?(loaded_flight.airplane)
    end

    test "get_flight!/1 returns the flight with given id" do
      flight = flight_fixture()
      assert Flights.get_flight!(flight.id) == flight
    end

    test "create_flight/1 with valid data creates a flight" do
      pilot = pilot_fixture()
      airplane = airplane_fixture()
      valid_attrs = %{hobbs_reading: "120.5", flight_date: ~D[2025-07-03], pilot_id: pilot.id, airplane_id: airplane.id}

      assert {:ok, %Flight{} = flight} = Flights.create_flight(valid_attrs)
      assert flight.hobbs_reading == Decimal.new("120.5")
      assert flight.flight_date == ~D[2025-07-03]
      assert flight.pilot_id == pilot.id
      assert flight.airplane_id == airplane.id
    end

    test "create_flight/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Flights.create_flight(@invalid_attrs)
    end

    test "update_flight/2 with valid data updates the flight" do
      flight = flight_fixture()
      update_attrs = %{hobbs_reading: "456.7", flight_date: ~D[2025-07-04]}

      assert {:ok, %Flight{} = flight} = Flights.update_flight(flight, update_attrs)
      assert flight.hobbs_reading == Decimal.new("456.7")
      assert flight.flight_date == ~D[2025-07-04]
    end

    test "update_flight/2 with invalid data returns error changeset" do
      flight = flight_fixture()
      assert {:error, %Ecto.Changeset{}} = Flights.update_flight(flight, @invalid_attrs)
      assert flight == Flights.get_flight!(flight.id)
    end

    test "delete_flight/1 deletes the flight" do
      flight = flight_fixture()
      assert {:ok, %Flight{}} = Flights.delete_flight(flight)
      assert_raise Ecto.NoResultsError, fn -> Flights.get_flight!(flight.id) end
    end

    test "change_flight/1 returns a flight changeset" do
      flight = flight_fixture()
      assert %Ecto.Changeset{} = Flights.change_flight(flight)
    end
  end

  describe "list_flights_for_airplane_month/2" do
    import FlightLog.FlightsFixtures
    import FlightLog.AccountsFixtures
    import FlightLog.AirplanesFixtures

    test "returns flights for specific airplane and month from all pilots" do
      pilot1 = pilot_fixture()
      pilot2 = pilot_fixture()
      airplane = airplane_fixture()
      date = ~D[2024-01-15]

      # Create flights for different pilots in the same month
      flight1 = flight_fixture(%{
        pilot_id: pilot1.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10]
      })

      flight2 = flight_fixture(%{
        pilot_id: pilot2.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20]
      })

      # Create flight in different month (should not appear)
      _flight_different_month = flight_fixture(%{
        pilot_id: pilot1.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-02-15]
      })

      # Create flight for different airplane (should not appear)
      other_airplane = airplane_fixture()
      _flight_different_airplane = flight_fixture(%{
        pilot_id: pilot1.id,
        airplane_id: other_airplane.id,
        flight_date: ~D[2024-01-25]
      })

      flights = Flights.list_flights_for_airplane_month(airplane.id, date)

      assert length(flights) == 2
      flight_ids = Enum.map(flights, & &1.id)
      assert flight1.id in flight_ids
      assert flight2.id in flight_ids

      # Verify flights are preloaded with pilot and airplane
      assert Enum.all?(flights, &Ecto.assoc_loaded?(&1.pilot))
      assert Enum.all?(flights, &Ecto.assoc_loaded?(&1.airplane))
    end

    test "returns empty list when no flights exist for airplane and month" do
      airplane = airplane_fixture()
      date = ~D[2024-01-15]

      flights = Flights.list_flights_for_airplane_month(airplane.id, date)
      assert flights == []
    end

    test "filters correctly by month boundaries" do
      pilot = pilot_fixture()
      airplane = airplane_fixture()

      # Flight at beginning of month
      flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-01]
      })

      # Flight at end of month
      flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-31]
      })

      # Flight just before month
      _flight_before = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2023-12-31]
      })

      # Flight just after month
      _flight_after = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-02-01]
      })

      flights = Flights.list_flights_for_airplane_month(airplane.id, ~D[2024-01-15])

      assert length(flights) == 2
      flight_ids = Enum.map(flights, & &1.id)
      assert flight1.id in flight_ids
      assert flight2.id in flight_ids
    end

    test "orders flights by date descending, then by inserted_at descending" do
      pilot1 = pilot_fixture()
      pilot2 = pilot_fixture()
      airplane = airplane_fixture()

      # Create flights in mixed order
      flight_middle = flight_fixture(%{
        pilot_id: pilot1.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        inserted_at: ~U[2024-01-15 10:00:00Z]
      })

      flight_latest = flight_fixture(%{
        pilot_id: pilot2.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        inserted_at: ~U[2024-01-20 14:00:00Z]
      })

      flight_earliest = flight_fixture(%{
        pilot_id: pilot1.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        inserted_at: ~U[2024-01-10 09:00:00Z]
      })

      flights = Flights.list_flights_for_airplane_month(airplane.id, ~D[2024-01-15])

      assert length(flights) == 3
      assert Enum.at(flights, 0).id == flight_latest.id
      assert Enum.at(flights, 1).id == flight_middle.id
      assert Enum.at(flights, 2).id == flight_earliest.id
    end
  end

      describe "add_flight_hours/1" do
    import FlightLog.FlightsFixtures
    import FlightLog.AccountsFixtures
    import FlightLog.AirplanesFixtures

    test "returns empty list for empty input" do
      assert Flights.add_flight_hours([]) == []
    end

    test "calculates flight hours from initial hobbs reading for single flight" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{initial_hobbs_reading: Decimal.new("50.0")})

      flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        hobbs_reading: Decimal.new("52.5"),
        flight_date: ~D[2024-01-15]
      })

      # Preload airplane data
      flight_with_airplane = FlightLog.Repo.preload(flight, :airplane)

      [result] = Flights.add_flight_hours([flight_with_airplane])
      assert result.flight_hours == Decimal.new("2.5")  # 52.5 - 50.0
      assert result.id == flight.id
    end

        test "calculates flight hours correctly for multiple flights" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{initial_hobbs_reading: Decimal.new("95.0")})

      # Create flights in reverse chronological order (newest first)
      flight3 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        hobbs_reading: Decimal.new("104.2"),
        inserted_at: ~U[2024-01-20 10:00:00Z]
      })

      flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("102.5"),
        inserted_at: ~U[2024-01-15 10:00:00Z]
      })

      flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("100.0"),
        inserted_at: ~U[2024-01-10 10:00:00Z]
      })

      # Preload airplane data
      flights_with_airplane = FlightLog.Repo.preload([flight3, flight2, flight1], :airplane)

      # Pass flights in newest-first order (original display order)
      results = Flights.add_flight_hours(flights_with_airplane)

      # Results should maintain original order
      assert length(results) == 3
      assert Enum.at(results, 0).id == flight3.id
      assert Enum.at(results, 1).id == flight2.id
      assert Enum.at(results, 2).id == flight1.id

      # Check flight hours calculations
      flight1_result = Enum.find(results, &(&1.id == flight1.id))
      flight2_result = Enum.find(results, &(&1.id == flight2.id))
      flight3_result = Enum.find(results, &(&1.id == flight3.id))

      assert flight1_result.flight_hours == Decimal.new("5.0")    # 100.0 - 95.0 (initial)
      assert flight2_result.flight_hours == Decimal.new("2.5")    # 102.5 - 100.0
      assert flight3_result.flight_hours == Decimal.new("1.7")    # 104.2 - 102.5
    end

        test "handles flights with same date correctly" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{initial_hobbs_reading: Decimal.new("48.0")})

      # Two flights on same date, different times
      flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("51.3"),
        inserted_at: ~U[2024-01-15 14:00:00Z]  # Later time
      })

      flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("50.0"),
        inserted_at: ~U[2024-01-15 09:00:00Z]  # Earlier time
      })

      # Preload airplane data
      flights_with_airplane = FlightLog.Repo.preload([flight2, flight1], :airplane)

      results = Flights.add_flight_hours(flights_with_airplane)

      flight1_result = Enum.find(results, &(&1.id == flight1.id))
      flight2_result = Enum.find(results, &(&1.id == flight2.id))

      assert flight1_result.flight_hours == Decimal.new("2.0")   # 50.0 - 48.0 (initial)
      assert flight2_result.flight_hours == Decimal.new("1.3")   # 51.3 - 50.0
    end

        test "preserves original flight order in results" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{initial_hobbs_reading: Decimal.new("80.0")})

      flight_a = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        hobbs_reading: Decimal.new("200.0")
      })

      flight_b = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("100.0")
      })

      # Preload airplane data
      flights_with_airplane = FlightLog.Repo.preload([flight_a, flight_b], :airplane)

      # Pass in specific order
      results = Flights.add_flight_hours(flights_with_airplane)

      # Should maintain same order
      assert Enum.at(results, 0).id == flight_a.id
      assert Enum.at(results, 1).id == flight_b.id

      # Check that flight_hours field was added to all
      assert Enum.all?(results, &Map.has_key?(&1, :flight_hours))
    end

    test "correctly calculates first flight hours from initial hobbs reading" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{initial_hobbs_reading: Decimal.new("1000.0")})

      flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("1003.7")
      })

      # Preload airplane data
      flight_with_airplane = FlightLog.Repo.preload(flight, :airplane)

      [result] = Flights.add_flight_hours([flight_with_airplane])

      # First flight hours should be hobbs_reading - initial_hobbs_reading
      assert result.flight_hours == Decimal.new("3.7")  # 1003.7 - 1000.0
      assert result.id == flight.id
    end

    test "calculates correct hours when viewing flights filtered by month (month boundary bug)" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{initial_hobbs_reading: Decimal.new("100.0")})

      # January flight: hobbs 110.0 -> 10 hours
      _jan_flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("110.0")
      })

      # February flight: hobbs 115.0 -> should be 5 hours (115 - 110)
      feb_flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-02-10],
        hobbs_reading: Decimal.new("115.0")
      })

      # Fetch only February flights (simulating monthly view)
      february_flights = Flights.list_flights_for_airplane_month(airplane.id, ~D[2024-02-15])

      assert length(february_flights) == 1
      assert hd(february_flights).id == feb_flight.id

      # Get the previous hobbs reading (from January flight)
      start_of_february = Date.beginning_of_month(~D[2024-02-15])
      previous_hobbs = Flights.get_previous_hobbs_reading(airplane.id, start_of_february)

      # Calculate hours for February flights with correct previous hobbs
      [result] = Flights.add_flight_hours(february_flights, previous_hobbs)

      # The February flight should show 5.0 hours (115.0 - 110.0)
      assert result.flight_hours == Decimal.new("5.0")
    end

    test "get_previous_hobbs_reading returns nil when no previous flights exist" do
      airplane = airplane_fixture()
      assert Flights.get_previous_hobbs_reading(airplane.id, ~D[2024-01-01]) == nil
    end

    test "uses initial_hobbs_reading when previous_hobbs is nil (no previous flights)" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{initial_hobbs_reading: Decimal.new("500.0")})

      # First ever flight for this airplane
      flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("503.5")
      })

      # Simulate monthly view: get flights for the month
      january_flights = Flights.list_flights_for_airplane_month(airplane.id, ~D[2024-01-15])

      # Get previous hobbs (should be nil since no flights before January)
      start_of_january = Date.beginning_of_month(~D[2024-01-15])
      previous_hobbs = Flights.get_previous_hobbs_reading(airplane.id, start_of_january)
      assert previous_hobbs == nil

      # Calculate hours - should use initial_hobbs_reading (500.0) since previous_hobbs is nil
      [result] = Flights.add_flight_hours(january_flights, previous_hobbs)

      # Flight hours should be 3.5 (503.5 - 500.0)
      assert result.flight_hours == Decimal.new("3.5")
    end

    test "get_previous_hobbs_reading returns the most recent hobbs reading before the given date" do
      pilot = pilot_fixture()
      airplane = airplane_fixture()

      # Create flights in different months
      _flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("100.0")
      })

      _flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-25],
        hobbs_reading: Decimal.new("110.0")
      })

      # Get previous hobbs reading before February - should be 110.0 (the January 25th flight)
      previous_hobbs = Flights.get_previous_hobbs_reading(airplane.id, ~D[2024-02-01])
      assert previous_hobbs == Decimal.new("110.0")

      # Get previous hobbs reading before January 20 - should be 100.0 (the January 10th flight)
      previous_hobbs_mid_jan = Flights.get_previous_hobbs_reading(airplane.id, ~D[2024-01-20])
      assert previous_hobbs_mid_jan == Decimal.new("100.0")
    end
  end
end
