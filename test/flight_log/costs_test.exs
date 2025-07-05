defmodule FlightLog.CostsTest do
  use FlightLog.DataCase

  alias FlightLog.Costs

  describe "costs" do
    alias FlightLog.Costs.Cost

    import FlightLog.CostsFixtures
    import FlightLog.AirplanesFixtures

    @invalid_attrs %{airplane_id: nil, cost_type: nil, amount: nil}

    test "list_costs_for_airplane/1 returns all costs for a given airplane" do
      airplane = airplane_fixture()
      cost1 = cost_fixture(airplane: airplane)
      cost2 = cost_fixture(airplane: airplane)
      other_airplane = airplane_fixture(%{tail_number: "OTHER-123"})
      _other_cost = cost_fixture(airplane: other_airplane)

      costs = Costs.list_costs_for_airplane(airplane.id)
      assert length(costs) == 2
      assert Enum.find(costs, &(&1.id == cost1.id))
      assert Enum.find(costs, &(&1.id == cost2.id))
    end

    test "list_costs_for_airplane/1 returns empty list when no costs exist" do
      airplane = airplane_fixture()
      assert Costs.list_costs_for_airplane(airplane.id) == []
    end

        test "list_costs_for_airplane/1 orders costs by type and then by insertion date" do
      airplane = airplane_fixture()

      # Create costs in different order
      _monthly_cost = monthly_cost_fixture(airplane: airplane)
      _one_time_cost = one_time_cost_fixture(airplane: airplane)
      _hourly_cost = hourly_cost_fixture(airplane: airplane)

      costs = Costs.list_costs_for_airplane(airplane.id)

      # Should be ordered by cost_type alphabetically (hourly, monthly, one_time)
      assert length(costs) == 3
      assert Enum.at(costs, 0).cost_type == :hourly
      assert Enum.at(costs, 1).cost_type == :monthly
      assert Enum.at(costs, 2).cost_type == :one_time
    end

    test "get_cost!/1 returns the cost with given id" do
      cost = cost_fixture()
      assert Costs.get_cost!(cost.id) == cost
    end

    test "get_cost!/1 raises when cost doesn't exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Costs.get_cost!(-1)
      end
    end

    test "create_cost/1 with valid data creates a cost" do
      airplane = airplane_fixture()
      valid_attrs = %{
        airplane_id: airplane.id,
        cost_type: :monthly,
        amount: "1200.50",
        description: "Monthly insurance premium"
      }

      assert {:ok, %Cost{} = cost} = Costs.create_cost(valid_attrs)
      assert cost.airplane_id == airplane.id
      assert cost.cost_type == :monthly
      assert cost.amount == Decimal.new("1200.50")
      assert cost.description == "Monthly insurance premium"
    end

    test "create_cost/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Costs.create_cost(@invalid_attrs)
    end

    test "create_cost/1 validates cost_type inclusion" do
      airplane = airplane_fixture()
      invalid_attrs = %{
        airplane_id: airplane.id,
        cost_type: :invalid_type,
        amount: "100.00"
      }

      assert {:error, changeset} = Costs.create_cost(invalid_attrs)
      assert %{cost_type: ["is invalid"]} = errors_on(changeset)
    end

    test "create_cost/1 validates amount is positive" do
      airplane = airplane_fixture()
      invalid_attrs = %{
        airplane_id: airplane.id,
        cost_type: :monthly,
        amount: "-100.00"
      }

      assert {:error, changeset} = Costs.create_cost(invalid_attrs)
      assert %{amount: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "create_cost/1 validates amount is not zero" do
      airplane = airplane_fixture()
      invalid_attrs = %{
        airplane_id: airplane.id,
        cost_type: :monthly,
        amount: "0.00"
      }

      assert {:error, changeset} = Costs.create_cost(invalid_attrs)
      assert %{amount: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "create_cost/1 validates airplane_id foreign key" do
      invalid_attrs = %{
        airplane_id: -1,
        cost_type: :monthly,
        amount: "100.00"
      }

      assert {:error, changeset} = Costs.create_cost(invalid_attrs)
      assert %{airplane_id: ["does not exist"]} = errors_on(changeset)
    end

    test "create_cost/1 allows description to be nil" do
      airplane = airplane_fixture()
      valid_attrs = %{
        airplane_id: airplane.id,
        cost_type: :hourly,
        amount: "50.00"
      }

      assert {:ok, %Cost{} = cost} = Costs.create_cost(valid_attrs)
      assert cost.description == nil
    end

    test "update_cost/2 with valid data updates the cost" do
      cost = cost_fixture()
      update_attrs = %{
        cost_type: :hourly,
        amount: "125.75",
        description: "Updated fuel cost"
      }

      assert {:ok, %Cost{} = cost} = Costs.update_cost(cost, update_attrs)
      assert cost.cost_type == :hourly
      assert cost.amount == Decimal.new("125.75")
      assert cost.description == "Updated fuel cost"
    end

    test "update_cost/2 with invalid data returns error changeset" do
      cost = cost_fixture()
      assert {:error, %Ecto.Changeset{}} = Costs.update_cost(cost, @invalid_attrs)
      assert cost == Costs.get_cost!(cost.id)
    end

    test "update_cost/2 validates cost_type inclusion" do
      cost = cost_fixture()
      invalid_attrs = %{cost_type: :invalid_type}

      assert {:error, changeset} = Costs.update_cost(cost, invalid_attrs)
      assert %{cost_type: ["is invalid"]} = errors_on(changeset)
    end

    test "update_cost/2 validates amount is positive" do
      cost = cost_fixture()
      invalid_attrs = %{amount: "-50.00"}

      assert {:error, changeset} = Costs.update_cost(cost, invalid_attrs)
      assert %{amount: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "delete_cost/1 deletes the cost" do
      cost = cost_fixture()
      assert {:ok, %Cost{}} = Costs.delete_cost(cost)
      assert_raise Ecto.NoResultsError, fn -> Costs.get_cost!(cost.id) end
    end

    test "change_cost/1 returns a cost changeset" do
      cost = cost_fixture()
      assert %Ecto.Changeset{} = Costs.change_cost(cost)
    end

    test "change_cost/2 returns a cost changeset with given attrs" do
      cost = cost_fixture()
      changeset = Costs.change_cost(cost, %{amount: "200.00"})
      assert %Ecto.Changeset{} = changeset
      assert changeset.changes.amount == Decimal.new("200.00")
    end

    test "airplane deletion cascades to costs" do
      airplane = airplane_fixture()
      cost = cost_fixture(airplane: airplane)

      # Delete the airplane
      FlightLog.Airplanes.delete_airplane(airplane)

      # Cost should be automatically deleted
      assert_raise Ecto.NoResultsError, fn -> Costs.get_cost!(cost.id) end
    end

    test "create_cost/1 with effective_date creates a cost with effective date" do
      airplane = airplane_fixture()
      effective_date = ~D[2024-06-15]
      valid_attrs = %{
        airplane_id: airplane.id,
        cost_type: :one_time,
        amount: "2500.00",
        description: "One-time maintenance",
        effective_date: effective_date
      }

      assert {:ok, %Cost{} = cost} = Costs.create_cost(valid_attrs)
      assert cost.airplane_id == airplane.id
      assert cost.cost_type == :one_time
      assert cost.amount == Decimal.new("2500.00")
      assert cost.description == "One-time maintenance"
      assert cost.effective_date == effective_date
    end

    test "create_cost/1 allows effective_date to be nil" do
      airplane = airplane_fixture()
      valid_attrs = %{
        airplane_id: airplane.id,
        cost_type: :monthly,
        amount: "1200.00",
        description: "Monthly cost"
      }

      assert {:ok, %Cost{} = cost} = Costs.create_cost(valid_attrs)
      assert cost.effective_date == nil
    end

    test "update_cost/2 with effective_date updates the cost" do
      cost = cost_fixture()
      effective_date = ~D[2024-03-20]
      update_attrs = %{
        cost_type: :one_time,
        amount: "1500.00",
        description: "Updated maintenance cost",
        effective_date: effective_date
      }

      assert {:ok, %Cost{} = updated_cost} = Costs.update_cost(cost, update_attrs)
      assert updated_cost.cost_type == :one_time
      assert updated_cost.amount == Decimal.new("1500.00")
      assert updated_cost.description == "Updated maintenance cost"
      assert updated_cost.effective_date == effective_date
    end

    test "update_cost/2 can set effective_date to nil" do
      cost = cost_with_effective_date_fixture()
      assert cost.effective_date != nil

      update_attrs = %{effective_date: nil}

      assert {:ok, %Cost{} = updated_cost} = Costs.update_cost(cost, update_attrs)
      assert updated_cost.effective_date == nil
    end

    test "change_cost/2 returns a cost changeset with effective_date" do
      cost = cost_fixture()
      effective_date = ~D[2024-05-10]
      changeset = Costs.change_cost(cost, %{effective_date: effective_date})
      assert %Ecto.Changeset{} = changeset
      assert changeset.changes.effective_date == effective_date
    end
  end

    describe "cost types" do
    alias FlightLog.Costs.Cost
    import FlightLog.AirplanesFixtures

    test "cost_types/0 returns all valid cost types" do
      types = Cost.cost_types()
      assert types == [:monthly, :hourly, :one_time]
    end

    test "all cost types are valid for creation" do
      airplane = airplane_fixture()

      for cost_type <- Cost.cost_types() do
        assert {:ok, %Cost{}} = Costs.create_cost(%{
          airplane_id: airplane.id,
          cost_type: cost_type,
          amount: "100.00",
          description: "Test #{cost_type} cost"
        })
      end
    end
  end

  describe "get_monthly_costs_for_airplane/3" do
    import FlightLog.AirplanesFixtures
    import FlightLog.CostsFixtures

    test "returns empty costs when no costs exist" do
      airplane = airplane_fixture()
      month_date = ~D[2024-01-01]
      total_flight_hours = Decimal.new("10.5")

      result = Costs.get_monthly_costs_for_airplane(airplane.id, month_date, total_flight_hours)

      assert result.monthly_costs == []
      assert result.hourly_costs == []
      assert result.one_time_costs == []
      assert result.total_monthly_cost == Decimal.new("0")
      assert result.total_hourly_cost == Decimal.new("0.0")
      assert result.total_one_time_cost == Decimal.new("0")
      assert result.total_cost == Decimal.new("0.0")
    end

    test "includes monthly costs effective before or during the month" do
      airplane = airplane_fixture()
      month_date = ~D[2024-01-01]
      total_flight_hours = Decimal.new("10.0")

      # Cost effective before the month
      monthly_cost_before = cost_fixture(%{airplane: airplane, cost_type: :monthly, amount: "500.00", description: "Insurance", effective_date: ~D[2023-12-01]})
      # Cost effective during the month
      monthly_cost_during = cost_fixture(%{airplane: airplane, cost_type: :monthly, amount: "600.00", description: "Hangar", effective_date: ~D[2024-01-15]})
      # Cost effective after the month (should not be included)
      _monthly_cost_after = cost_fixture(%{airplane: airplane, cost_type: :monthly, amount: "700.00", description: "Subscription", effective_date: ~D[2024-02-01]})

      result = Costs.get_monthly_costs_for_airplane(airplane.id, month_date, total_flight_hours)

      assert length(result.monthly_costs) == 2
      cost_ids = Enum.map(result.monthly_costs, & &1.id)
      assert monthly_cost_before.id in cost_ids
      assert monthly_cost_during.id in cost_ids
      assert result.total_monthly_cost == Decimal.new("1100.00")
    end

    test "includes hourly costs effective before or during the month and multiplies by flight hours" do
      airplane = airplane_fixture()
      month_date = ~D[2024-01-01]
      total_flight_hours = Decimal.new("5.5")

      # Cost effective before the month
      hourly_cost_before = cost_fixture(%{airplane: airplane, cost_type: :hourly, amount: "125.00", description: "Fuel", effective_date: ~D[2023-12-01]})
      # Cost effective during the month
      hourly_cost_during = cost_fixture(%{airplane: airplane, cost_type: :hourly, amount: "150.00", description: "Maintenance", effective_date: ~D[2024-01-15]})
      # Cost effective after the month (should not be included)
      _hourly_cost_after = cost_fixture(%{airplane: airplane, cost_type: :hourly, amount: "175.00", description: "Oil", effective_date: ~D[2024-02-01]})

      result = Costs.get_monthly_costs_for_airplane(airplane.id, month_date, total_flight_hours)

      assert length(result.hourly_costs) == 2
      cost_ids = Enum.map(result.hourly_costs, & &1.id)
      assert hourly_cost_before.id in cost_ids
      assert hourly_cost_during.id in cost_ids
      # Total hourly cost should be (125 + 150) * 5.5 = 275 * 5.5 = 1512.50
      assert result.total_hourly_cost == Decimal.new("1512.500")
    end

    test "includes one-time costs effective within the month only" do
      airplane = airplane_fixture()
      month_date = ~D[2024-01-01]
      total_flight_hours = Decimal.new("10.0")

      # Cost effective before the month (should not be included)
      _one_time_cost_before = cost_fixture(%{airplane: airplane, cost_type: :one_time, amount: "1000.00", effective_date: ~D[2023-12-15]})
      # Cost effective during the month
      one_time_cost_during = cost_fixture(%{airplane: airplane, cost_type: :one_time, amount: "2500.00", effective_date: ~D[2024-01-15]})
      # Cost effective after the month (should not be included)
      _one_time_cost_after = cost_fixture(%{airplane: airplane, cost_type: :one_time, amount: "3000.00", effective_date: ~D[2024-02-01]})

      result = Costs.get_monthly_costs_for_airplane(airplane.id, month_date, total_flight_hours)

      assert length(result.one_time_costs) == 1
      assert List.first(result.one_time_costs).id == one_time_cost_during.id
      assert result.total_one_time_cost == Decimal.new("2500.00")
    end

    test "calculates total cost correctly" do
      airplane = airplane_fixture()
      month_date = ~D[2024-01-01]
      total_flight_hours = Decimal.new("2.0")

      # Monthly cost: 500.00
      _monthly_cost = cost_fixture(%{airplane: airplane, cost_type: :monthly, amount: "500.00", description: "Insurance", effective_date: ~D[2024-01-01]})
      # Hourly cost: 100.00 * 2.0 = 200.00
      _hourly_cost = cost_fixture(%{airplane: airplane, cost_type: :hourly, amount: "100.00", description: "Fuel", effective_date: ~D[2024-01-01]})
      # One-time cost: 1000.00
      _one_time_cost = cost_fixture(%{airplane: airplane, cost_type: :one_time, amount: "1000.00", description: "Maintenance", effective_date: ~D[2024-01-15]})

      result = Costs.get_monthly_costs_for_airplane(airplane.id, month_date, total_flight_hours)

      # Total: 500.00 + 200.00 + 1000.00 = 1700.00
      assert result.total_cost == Decimal.new("1700.000")
    end

    test "handles nil effective_date for monthly and hourly costs" do
      airplane = airplane_fixture()
      month_date = ~D[2024-01-01]
      total_flight_hours = Decimal.new("3.0")

      # Monthly cost with nil effective_date (should be included)
      monthly_cost = cost_fixture(%{airplane: airplane, cost_type: :monthly, amount: "800.00", description: "Insurance", effective_date: nil})
      # Hourly cost with nil effective_date (should be included)
      hourly_cost = cost_fixture(%{airplane: airplane, cost_type: :hourly, amount: "90.00", description: "Fuel", effective_date: nil})

      result = Costs.get_monthly_costs_for_airplane(airplane.id, month_date, total_flight_hours)

      assert length(result.monthly_costs) == 1
      assert List.first(result.monthly_costs).id == monthly_cost.id
      assert result.total_monthly_cost == Decimal.new("800.00")

      assert length(result.hourly_costs) == 1
      assert List.first(result.hourly_costs).id == hourly_cost.id
      assert result.total_hourly_cost == Decimal.new("270.000")  # 90.00 * 3.0
    end

    test "gets latest cost for each description for monthly and hourly costs" do
      airplane = airplane_fixture()
      month_date = ~D[2024-01-01]
      total_flight_hours = Decimal.new("1.0")

            # Two monthly costs with same description, different effective dates
      _old_monthly_cost = cost_fixture(%{airplane: airplane, cost_type: :monthly, amount: "400.00",
                                       description: "Insurance", effective_date: ~D[2023-11-01]})
      new_monthly_cost = cost_fixture(%{airplane: airplane, cost_type: :monthly, amount: "450.00",
                                      description: "Insurance", effective_date: ~D[2023-12-01]})

      # Two hourly costs with same description, different effective dates
      _old_hourly_cost = cost_fixture(%{airplane: airplane, cost_type: :hourly, amount: "120.00",
                                      description: "Fuel", effective_date: ~D[2023-11-01]})
      new_hourly_cost = cost_fixture(%{airplane: airplane, cost_type: :hourly, amount: "130.00",
                                     description: "Fuel", effective_date: ~D[2023-12-01]})

      result = Costs.get_monthly_costs_for_airplane(airplane.id, month_date, total_flight_hours)

      # Should only get the latest cost for each description
      assert length(result.monthly_costs) == 1
      assert List.first(result.monthly_costs).id == new_monthly_cost.id
      assert result.total_monthly_cost == Decimal.new("450.00")

      assert length(result.hourly_costs) == 1
      assert List.first(result.hourly_costs).id == new_hourly_cost.id
      assert result.total_hourly_cost == Decimal.new("130.000")  # 130.00 * 1.0
    end

    test "handles zero flight hours correctly" do
      airplane = airplane_fixture()
      month_date = ~D[2024-01-01]
      total_flight_hours = Decimal.new("0")

      _monthly_cost = cost_fixture(%{airplane: airplane, cost_type: :monthly, amount: "500.00", description: "Insurance", effective_date: ~D[2024-01-01]})
      _hourly_cost = cost_fixture(%{airplane: airplane, cost_type: :hourly, amount: "100.00", description: "Fuel", effective_date: ~D[2024-01-01]})

      result = Costs.get_monthly_costs_for_airplane(airplane.id, month_date, total_flight_hours)

      assert result.total_monthly_cost == Decimal.new("500.00")
      assert result.total_hourly_cost == Decimal.new("0.00")  # 100.00 * 0 = 0
      assert result.total_cost == Decimal.new("500.00")
    end

    test "filters costs by airplane_id" do
      airplane1 = airplane_fixture()
      airplane2 = airplane_fixture(%{tail_number: "DIFF-123"})
      month_date = ~D[2024-01-01]
      total_flight_hours = Decimal.new("5.0")

      # Costs for airplane1
      _cost1 = cost_fixture(%{airplane: airplane1, cost_type: :monthly, amount: "500.00", description: "Insurance", effective_date: ~D[2024-01-01]})
      # Costs for airplane2 (should not be included)
      _cost2 = cost_fixture(%{airplane: airplane2, cost_type: :monthly, amount: "600.00", description: "Insurance", effective_date: ~D[2024-01-01]})

      result = Costs.get_monthly_costs_for_airplane(airplane1.id, month_date, total_flight_hours)

      assert length(result.monthly_costs) == 1
      assert List.first(result.monthly_costs).airplane_id == airplane1.id
      assert result.total_monthly_cost == Decimal.new("500.00")
    end
  end
end
