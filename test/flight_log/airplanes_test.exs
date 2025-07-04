defmodule FlightLog.AirplanesTest do
  use FlightLog.DataCase

  alias FlightLog.Airplanes

  describe "airplanes" do
    alias FlightLog.Airplanes.Airplane

    import FlightLog.AirplanesFixtures

    @invalid_attrs %{year: nil, make: nil, tail_number: nil, initial_hobbs_reading: nil, model: nil}

    test "list_airplanes/0 returns all airplanes" do
      airplane = airplane_fixture()
      assert Airplanes.list_airplanes() == [airplane]
    end

    test "get_airplane!/1 returns the airplane with given id" do
      airplane = airplane_fixture()
      assert Airplanes.get_airplane!(airplane.id) == airplane
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
  end
end
