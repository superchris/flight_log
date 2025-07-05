defmodule FlightLog.Costs do
  @moduledoc """
  The Costs context.
  """

  import Ecto.Query, warn: false
  alias FlightLog.Repo

  alias FlightLog.Costs.Cost

  @doc """
  Returns the list of costs for a given airplane.

  ## Examples

      iex> list_costs_for_airplane(airplane_id)
      [%Cost{}, ...]

  """
  def list_costs_for_airplane(airplane_id) do
    from(c in Cost,
      where: c.airplane_id == ^airplane_id,
      order_by: [asc: c.cost_type, asc: c.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns costs for a given airplane and month, with calculated amounts.

  ## Examples

      iex> get_monthly_costs_for_airplane(airplane_id, ~D[2024-01-01], Decimal.new("10.5"))
      %{
        monthly_costs: [%Cost{}],
        hourly_costs: [%Cost{}],
        one_time_costs: [%Cost{}],
        total_monthly_cost: Decimal.new("1200.00"),
        total_hourly_cost: Decimal.new("1317.50"),
        total_one_time_cost: Decimal.new("2500.00"),
        total_cost: Decimal.new("5017.50")
      }

  """
  def get_monthly_costs_for_airplane(airplane_id, month_date, total_flight_hours) do
    start_of_month = Date.beginning_of_month(month_date)
    end_of_month = Date.end_of_month(month_date)

    # Get costs by type with appropriate date filtering
    monthly_costs = get_effective_costs(airplane_id, :monthly, nil, end_of_month)
    hourly_costs = get_effective_costs(airplane_id, :hourly, nil, end_of_month)
    one_time_costs = get_effective_costs(airplane_id, :one_time, start_of_month, end_of_month)

    # Calculate totals
    total_monthly_cost = calculate_total_amount(monthly_costs)
    total_hourly_cost = calculate_total_amount(hourly_costs) |> Decimal.mult(total_flight_hours)
    total_one_time_cost = calculate_total_amount(one_time_costs)
    total_cost = [total_monthly_cost, total_hourly_cost, total_one_time_cost]
                 |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)

    %{
      monthly_costs: monthly_costs,
      hourly_costs: hourly_costs,
      one_time_costs: one_time_costs,
      total_monthly_cost: total_monthly_cost,
      total_hourly_cost: total_hourly_cost,
      total_one_time_cost: total_one_time_cost,
      total_cost: total_cost
    }
  end

  # Helper function to get costs by type with date filtering
  defp get_effective_costs(airplane_id, cost_type, start_date, end_date) do
    order_by = build_order_by(cost_type)

    query = from(c in Cost,
      where: c.airplane_id == ^airplane_id and c.cost_type == ^cost_type,
      order_by: ^order_by
    )

    query
    |> add_date_filter(start_date, end_date)
    |> Repo.all()
    |> maybe_get_latest_by_description(cost_type)
  end

  # Build appropriate ordering based on cost type
  defp build_order_by(:one_time), do: [asc: :effective_date]
  defp build_order_by(_), do: [desc: :effective_date, desc: :inserted_at]

  # Add date filtering to query based on cost type
  defp add_date_filter(query, nil, end_date) do
    # For monthly and hourly costs: effective before or during the month
    from(c in query, where: is_nil(c.effective_date) or c.effective_date <= ^end_date)
  end

  defp add_date_filter(query, start_date, end_date) do
    # For one-time costs: effective within the month only
    from(c in query, where: c.effective_date >= ^start_date and c.effective_date <= ^end_date)
  end

  # Apply latest cost filtering for monthly and hourly costs only
  defp maybe_get_latest_by_description(costs, cost_type) when cost_type in [:monthly, :hourly] do
    get_latest_costs_by_description(costs)
  end

  defp maybe_get_latest_by_description(costs, _cost_type), do: costs

  # Helper function to calculate total amount from a list of costs
  defp calculate_total_amount(costs) do
    costs
    |> Enum.map(& &1.amount)
    |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)
  end

  # Helper function to get the latest cost for each description
  # This ensures we only get the most recent cost for each type
  defp get_latest_costs_by_description(costs) do
    costs
    |> Enum.group_by(& (&1.description || "default"))
    |> Enum.map(fn {_description, costs_group} ->
      costs_group
      |> Enum.sort_by(&{&1.effective_date || ~D[1900-01-01], &1.inserted_at}, :desc)
      |> List.first()
    end)
  end

  @doc """
  Gets a single cost.

  Raises `Ecto.NoResultsError` if the Cost does not exist.

  ## Examples

      iex> get_cost!(123)
      %Cost{}

      iex> get_cost!(456)
      ** (Ecto.NoResultsError)

  """
  def get_cost!(id), do: Repo.get!(Cost, id)

  @doc """
  Creates a cost.

  ## Examples

      iex> create_cost(%{field: value})
      {:ok, %Cost{}}

      iex> create_cost(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_cost(attrs \\ %{}) do
    %Cost{}
    |> Cost.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a cost.

  ## Examples

      iex> update_cost(cost, %{field: new_value})
      {:ok, %Cost{}}

      iex> update_cost(cost, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_cost(%Cost{} = cost, attrs) do
    cost
    |> Cost.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a cost.

  ## Examples

      iex> delete_cost(cost)
      {:ok, %Cost{}}

      iex> delete_cost(cost)
      {:error, %Ecto.Changeset{}}

  """
  def delete_cost(%Cost{} = cost) do
    Repo.delete(cost)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking cost changes.

  ## Examples

      iex> change_cost(cost)
      %Ecto.Changeset{data: %Cost{}}

  """
  def change_cost(%Cost{} = cost, attrs \\ %{}) do
    Cost.changeset(cost, attrs)
  end
end
