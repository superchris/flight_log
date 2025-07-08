defmodule FlightLog.Flights do
  @moduledoc """
  The Flights context.
  """

  import Ecto.Query, warn: false
  alias FlightLog.Repo

  alias FlightLog.Flights.Flight

  @doc """
  Returns the list of flights.

  ## Examples

      iex> list_flights()
      [%Flight{}, ...]

  """
  def list_flights do
    from(f in Flight,
      order_by: [desc: f.flight_date, desc: f.inserted_at],
      preload: [:pilot, :airplane]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of flights for a specific pilot, airplane, and month.

  ## Examples

      iex> list_flights_for_pilot_airplane_month(1, 2, ~D[2024-01-01])
      [%Flight{}, ...]

  """
  def list_flights_for_pilot_airplane_month(pilot_id, airplane_id, date) do
    start_of_month = Date.beginning_of_month(date)
    end_of_month = Date.end_of_month(date)

    from(f in Flight,
      where: f.pilot_id == ^pilot_id,
      where: f.airplane_id == ^airplane_id,
      where: f.flight_date >= ^start_of_month,
      where: f.flight_date <= ^end_of_month,
      order_by: [desc: f.flight_date, desc: f.inserted_at],
      preload: [:pilot, :airplane]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of flights for a specific airplane and month (all pilots).

  ## Examples

      iex> list_flights_for_airplane_month(2, ~D[2024-01-01])
      [%Flight{}, ...]

  """
  def list_flights_for_airplane_month(airplane_id, date) do
    start_of_month = Date.beginning_of_month(date)
    end_of_month = Date.end_of_month(date)

    from(f in Flight,
      where: f.airplane_id == ^airplane_id,
      where: f.flight_date >= ^start_of_month,
      where: f.flight_date <= ^end_of_month,
      order_by: [desc: f.flight_date, desc: f.inserted_at],
      preload: [:pilot, :airplane]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single flight.

  Raises `Ecto.NoResultsError` if the Flight does not exist.

  ## Examples

      iex> get_flight!(123)
      %Flight{}

      iex> get_flight!(456)
      ** (Ecto.NoResultsError)

  """
  def get_flight!(id), do: Repo.get!(Flight, id)

  @doc """
  Creates a flight.

  ## Examples

      iex> create_flight(%{field: value})
      {:ok, %Flight{}}

      iex> create_flight(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_flight(attrs \\ %{}) do
    %Flight{}
    |> Flight.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a flight.

  ## Examples

      iex> update_flight(flight, %{field: new_value})
      {:ok, %Flight{}}

      iex> update_flight(flight, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_flight(%Flight{} = flight, attrs) do
    flight
    |> Flight.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a flight.

  ## Examples

      iex> delete_flight(flight)
      {:ok, %Flight{}}

      iex> delete_flight(flight)
      {:error, %Ecto.Changeset{}}

  """
  def delete_flight(%Flight{} = flight) do
    Repo.delete(flight)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking flight changes.

  ## Examples

      iex> change_flight(flight)
      %Ecto.Changeset{data: %Flight{}}

  """
  def change_flight(%Flight{} = flight, attrs \\ %{}) do
    Flight.changeset(flight, attrs)
  end

  @doc """
  Adds flight hours to each flight in the list.

  Flight hours are calculated as:
  - First flight (chronologically): hobbs_reading - airplane.initial_hobbs_reading
  - Subsequent flights: current_hobbs_reading - previous_hobbs_reading

  Returns flights in their original order with :flight_hours field added.
  Expects flights to have airplane preloaded.
  """
  def add_flight_hours([]), do: []

  def add_flight_hours(flights) when is_list(flights) do
    flights
    |> sort_chronologically()
    |> calculate_flight_hours()
    |> restore_original_order(flights)
  end

  defp sort_chronologically(flights) do
    Enum.sort_by(flights, &{&1.flight_date, &1.inserted_at}, :asc)
  end

  defp calculate_flight_hours([]), do: []

  defp calculate_flight_hours([first | rest]) do
    # Calculate first flight hours using airplane's initial hobbs reading
    initial_hobbs_reading = first.airplane.initial_hobbs_reading

    first_with_hours =
      Map.put(first, :flight_hours, Decimal.sub(first.hobbs_reading, initial_hobbs_reading))

    # Calculate remaining flights
    remaining_with_hours = Enum.scan(rest, first, &add_hours_to_flight(&1, &2))

    [first_with_hours | remaining_with_hours]
  end

  defp add_hours_to_flight(current_flight, previous_flight) do
    flight_hours = Decimal.sub(current_flight.hobbs_reading, previous_flight.hobbs_reading)
    Map.put(current_flight, :flight_hours, flight_hours)
  end

  defp restore_original_order(flights_with_hours, original_flights) do
    # Create a map for quick lookup
    hours_map = Map.new(flights_with_hours, &{&1.id, &1.flight_hours})

    # Add flight_hours to original flights maintaining their order
    Enum.map(original_flights, fn flight ->
      Map.put(flight, :flight_hours, Map.get(hours_map, flight.id))
    end)
  end
end
