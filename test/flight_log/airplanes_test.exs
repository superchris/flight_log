defmodule FlightLog.AirplanesTest do
  use FlightLog.DataCase

  alias FlightLog.Airplanes

  describe "airplanes" do
    alias FlightLog.Airplanes.Airplane

    import FlightLog.AirplanesFixtures
    import FlightLog.AccountsFixtures

    @invalid_attrs %{year: nil, make: nil, tail_number: nil, initial_hobbs_reading: nil, model: nil}

    test "list_airplanes/0 returns all airplanes" do
      airplane = airplane_fixture()
      assert Airplanes.list_airplanes() == [airplane]
    end

    test "get_airplane!/1 returns the airplane with given id" do
      airplane = airplane_fixture()
      assert Airplanes.get_airplane!(airplane.id) == airplane
    end

    test "get_airplane_by_tail_number/1 returns {:ok, airplane} when airplane exists" do
      airplane = airplane_fixture()
      assert {:ok, returned_airplane} = Airplanes.get_airplane_by_tail_number(airplane.tail_number)
      assert returned_airplane.id == airplane.id
      assert returned_airplane.tail_number == airplane.tail_number
    end

    test "get_airplane_by_tail_number/1 returns {:error, :not_found} when airplane does not exist" do
      assert {:error, :not_found} = Airplanes.get_airplane_by_tail_number("NONEXISTENT")
    end

    test "get_airplane_by_tail_number/1 returns {:error, :not_found} for empty string" do
      assert {:error, :not_found} = Airplanes.get_airplane_by_tail_number("")
    end

    test "get_airplane_by_tail_number/1 is case sensitive" do
      _airplane = airplane_fixture(%{tail_number: "N12345"})
      assert {:ok, _} = Airplanes.get_airplane_by_tail_number("N12345")
      assert {:error, :not_found} = Airplanes.get_airplane_by_tail_number("n12345")
    end

    test "create_airplane/1 with valid data creates a airplane" do
      valid_attrs = %{year: 42, make: "some make", tail_number: "some tail_number", initial_hobbs_reading: "120.5", model: "some model"}

      assert {:ok, %Airplane{} = airplane} = Airplanes.create_airplane(valid_attrs)
      assert airplane.year == 42
      assert airplane.make == "some make"
      assert airplane.tail_number == "some tail_number"
      assert airplane.initial_hobbs_reading == Decimal.new("120.5")
      assert airplane.model == "some model"
    end

    test "create_airplane/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Airplanes.create_airplane(@invalid_attrs)
    end

    test "update_airplane/2 with valid data updates the airplane" do
      airplane = airplane_fixture()
      update_attrs = %{year: 43, make: "some updated make", tail_number: "some updated tail_number", initial_hobbs_reading: "456.7", model: "some updated model"}

      assert {:ok, %Airplane{} = airplane} = Airplanes.update_airplane(airplane, update_attrs)
      assert airplane.year == 43
      assert airplane.make == "some updated make"
      assert airplane.tail_number == "some updated tail_number"
      assert airplane.initial_hobbs_reading == Decimal.new("456.7")
      assert airplane.model == "some updated model"
    end

    test "update_airplane/2 with invalid data returns error changeset" do
      airplane = airplane_fixture()
      assert {:error, %Ecto.Changeset{}} = Airplanes.update_airplane(airplane, @invalid_attrs)
      assert airplane == Airplanes.get_airplane!(airplane.id)
    end

    test "delete_airplane/1 deletes the airplane" do
      airplane = airplane_fixture()
      assert {:ok, %Airplane{}} = Airplanes.delete_airplane(airplane)
      assert_raise Ecto.NoResultsError, fn -> Airplanes.get_airplane!(airplane.id) end
    end

    test "change_airplane/1 returns a airplane changeset" do
      airplane = airplane_fixture()
      assert %Ecto.Changeset{} = Airplanes.change_airplane(airplane)
    end

    test "airplane can have multiple pilots" do
      pilot1 = pilot_fixture()
      pilot2 = pilot_fixture(%{email: "pilot2@example.com"})
      {:ok, airplane} = Airplanes.create_airplane(%{year: 42, make: "some make", tail_number: "N12345", initial_hobbs_reading: "120.5", model: "some model"})

      {:ok, airplane} = Airplanes.add_pilot_to_airplane(airplane, pilot1)
      {:ok, airplane} = Airplanes.add_pilot_to_airplane(airplane, pilot2)

      airplane_with_pilots = FlightLog.Repo.preload(airplane, :pilots)
      pilot_ids = Enum.map(airplane_with_pilots.pilots, & &1.id)

      assert length(airplane_with_pilots.pilots) == 2
      assert pilot1.id in pilot_ids
      assert pilot2.id in pilot_ids
    end

    test "pilot can have multiple airplanes" do
      pilot = pilot_fixture()
      airplane1 = airplane_fixture(%{pilot: pilot, tail_number: "N12345"})
      airplane2 = airplane_fixture(%{pilot: pilot, tail_number: "N67890"})

      pilot_with_airplanes = FlightLog.Repo.preload(pilot, :airplanes)
      airplane_ids = Enum.map(pilot_with_airplanes.airplanes, & &1.id)

      assert length(pilot_with_airplanes.airplanes) == 2
      assert airplane1.id in airplane_ids
      assert airplane2.id in airplane_ids
    end

    test "add_pilot_to_airplane/2 associates pilot with airplane" do
      pilot = pilot_fixture()
      {:ok, airplane} = Airplanes.create_airplane(%{year: 42, make: "some make", tail_number: "N12345", initial_hobbs_reading: "120.5", model: "some model"})

      {:ok, airplane} = Airplanes.add_pilot_to_airplane(airplane, pilot)

      airplane_with_pilots = FlightLog.Repo.preload(airplane, :pilots)
      assert length(airplane_with_pilots.pilots) == 1
      assert hd(airplane_with_pilots.pilots).id == pilot.id
    end

    test "remove_pilot_from_airplane/2 dissociates pilot from airplane" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{pilot: pilot, tail_number: "N12345"})

      {:ok, airplane} = Airplanes.remove_pilot_from_airplane(airplane, pilot)

      airplane_with_pilots = FlightLog.Repo.preload(airplane, :pilots)
      assert Enum.empty?(airplane_with_pilots.pilots)
    end

    test "list_airplanes_for_pilot/1 returns all airplanes for a pilot" do
      pilot = pilot_fixture()
      airplane1 = airplane_fixture(%{pilot: pilot, tail_number: "N12345"})
      airplane2 = airplane_fixture(%{pilot: pilot, tail_number: "N67890"})
      _other_airplane = airplane_fixture(%{tail_number: "N11111"})

      airplanes = Airplanes.list_airplanes_for_pilot(pilot)
      airplane_ids = Enum.map(airplanes, & &1.id)

      assert length(airplanes) == 2
      assert airplane1.id in airplane_ids
      assert airplane2.id in airplane_ids
    end

    test "get_airplane_for_pilot/2 returns {:ok, airplane} when pilot is associated" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{pilot: pilot, tail_number: "N12345"})

      assert {:ok, returned_airplane} = Airplanes.get_airplane_for_pilot(airplane.id, pilot)
      assert returned_airplane.id == airplane.id
    end

    test "get_airplane_for_pilot/2 returns {:error, :not_authorized} when pilot is not associated" do
      pilot = pilot_fixture()
      other_pilot = pilot_fixture()
      airplane = airplane_fixture(%{pilot: other_pilot, tail_number: "N12345"})

      assert {:error, :not_authorized} = Airplanes.get_airplane_for_pilot(airplane.id, pilot)
    end

    test "get_airplane_for_pilot/2 returns {:error, :not_found} when airplane does not exist" do
      pilot = pilot_fixture()

      assert {:error, :not_found} = Airplanes.get_airplane_for_pilot(-1, pilot)
    end
  end
end
