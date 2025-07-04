defmodule FlightLog.FlightsTest do
  use FlightLog.DataCase

  alias FlightLog.Flights

  describe "flights" do
    alias FlightLog.Flights.Flight

    import FlightLog.FlightsFixtures

    @invalid_attrs %{hobbs_reading: nil, flight_date: nil}

    test "list_flights/0 returns all flights" do
      flight = flight_fixture()
      assert Flights.list_flights() == [flight]
    end

    test "get_flight!/1 returns the flight with given id" do
      flight = flight_fixture()
      assert Flights.get_flight!(flight.id) == flight
    end

    test "create_flight/1 with valid data creates a flight" do
      valid_attrs = %{hobbs_reading: "120.5", flight_date: ~D[2025-07-03]}

      assert {:ok, %Flight{} = flight} = Flights.create_flight(valid_attrs)
      assert flight.hobbs_reading == Decimal.new("120.5")
      assert flight.flight_date == ~D[2025-07-03]
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
end
