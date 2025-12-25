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
      pilot = pilot_fixture()
      valid_attrs = %{year: 42, make: "some make", tail_number: "some tail_number", initial_hobbs_reading: "120.5", model: "some model", pilot_id: pilot.id}

      assert {:ok, %Airplane{} = airplane} = Airplanes.create_airplane(valid_attrs)
      assert airplane.year == 42
      assert airplane.make == "some make"
      assert airplane.tail_number == "some tail_number"
      assert airplane.initial_hobbs_reading == Decimal.new("120.5")
      assert airplane.model == "some model"
      assert airplane.pilot_id == pilot.id
    end

    test "create_airplane/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Airplanes.create_airplane(@invalid_attrs)
    end

    test "update_airplane/2 with valid data updates the airplane" do
      airplane = airplane_fixture()
      new_pilot = pilot_fixture()
      update_attrs = %{year: 43, make: "some updated make", tail_number: "some updated tail_number", initial_hobbs_reading: "456.7", model: "some updated model", pilot_id: new_pilot.id}

      assert {:ok, %Airplane{} = airplane} = Airplanes.update_airplane(airplane, update_attrs)
      assert airplane.year == 43
      assert airplane.make == "some updated make"
      assert airplane.tail_number == "some updated tail_number"
      assert airplane.initial_hobbs_reading == Decimal.new("456.7")
      assert airplane.model == "some updated model"
      assert airplane.pilot_id == new_pilot.id
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

    test "airplane belongs to pilot" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{pilot_id: pilot.id})

      airplane_with_pilot = FlightLog.Repo.preload(airplane, :pilot)
      assert airplane_with_pilot.pilot.id == pilot.id
      assert airplane_with_pilot.pilot.first_name == pilot.first_name
    end

    test "pilot has many airplanes" do
      pilot = pilot_fixture()
      airplane1 = airplane_fixture(%{pilot_id: pilot.id, tail_number: "N12345"})
      airplane2 = airplane_fixture(%{pilot_id: pilot.id, tail_number: "N67890"})

      pilot_with_airplanes = FlightLog.Repo.preload(pilot, :airplanes)
      airplane_ids = Enum.map(pilot_with_airplanes.airplanes, & &1.id)

      assert length(pilot_with_airplanes.airplanes) == 2
      assert airplane1.id in airplane_ids
      assert airplane2.id in airplane_ids
    end
  end
end
