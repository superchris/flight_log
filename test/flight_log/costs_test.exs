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
end
