defmodule FlightLog.FlightsTest do
  use FlightLog.DataCase

  alias FlightLog.Flights

  describe "flights" do
    alias FlightLog.Flights.Flight

    import FlightLog.FlightsFixtures
    import FlightLog.AccountsFixtures
    import FlightLog.AirplanesFixtures

    @invalid_attrs %{hobbs_reading: nil, flight_date: nil, pilot_id: nil, airplane_id: nil}

    test "list_flights/0 returns all flights" do
      flight = flight_fixture()
      assert Flights.list_flights() == [flight]
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

  describe "add_flight_hours/1" do
    import FlightLog.FlightsFixtures
    import FlightLog.AccountsFixtures
    import FlightLog.AirplanesFixtures

    test "returns empty list for empty input" do
      assert Flights.add_flight_hours([]) == []
    end

    test "adds flight hours to single flight" do
      pilot = pilot_fixture()
      airplane = airplane_fixture()

      flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        hobbs_reading: Decimal.new("10.5"),
        flight_date: ~D[2024-01-15]
      })

      [result] = Flights.add_flight_hours([flight])
      assert result.flight_hours == Decimal.new("10.5")
      assert result.id == flight.id
    end

    test "calculates flight hours correctly for multiple flights" do
      pilot = pilot_fixture()
      airplane = airplane_fixture()

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

      # Pass flights in newest-first order (original display order)
      results = Flights.add_flight_hours([flight3, flight2, flight1])

      # Results should maintain original order
      assert length(results) == 3
      assert Enum.at(results, 0).id == flight3.id
      assert Enum.at(results, 1).id == flight2.id
      assert Enum.at(results, 2).id == flight1.id

      # Check flight hours calculations
      flight1_result = Enum.find(results, &(&1.id == flight1.id))
      flight2_result = Enum.find(results, &(&1.id == flight2.id))
      flight3_result = Enum.find(results, &(&1.id == flight3.id))

      assert flight1_result.flight_hours == Decimal.new("100.0")  # First flight
      assert flight2_result.flight_hours == Decimal.new("2.5")    # 102.5 - 100.0
      assert flight3_result.flight_hours == Decimal.new("1.7")    # 104.2 - 102.5
    end

    test "handles flights with same date correctly" do
      pilot = pilot_fixture()
      airplane = airplane_fixture()

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

      results = Flights.add_flight_hours([flight2, flight1])

      flight1_result = Enum.find(results, &(&1.id == flight1.id))
      flight2_result = Enum.find(results, &(&1.id == flight2.id))

      assert flight1_result.flight_hours == Decimal.new("50.0")  # First chronologically
      assert flight2_result.flight_hours == Decimal.new("1.3")   # 51.3 - 50.0
    end

    test "preserves original flight order in results" do
      pilot = pilot_fixture()
      airplane = airplane_fixture()

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

      # Pass in specific order
      results = Flights.add_flight_hours([flight_a, flight_b])

      # Should maintain same order
      assert Enum.at(results, 0).id == flight_a.id
      assert Enum.at(results, 1).id == flight_b.id

      # Check that flight_hours field was added to all
      assert Enum.all?(results, &Map.has_key?(&1, :flight_hours))
    end
  end
end
