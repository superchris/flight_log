defmodule FlightLog.Airplanes do
  @moduledoc """
  The Airplanes context.
  """

  import Ecto.Query, warn: false
  alias FlightLog.Repo

  alias FlightLog.Airplanes.Airplane

  @doc """
  Returns the list of airplanes.

  ## Examples

      iex> list_airplanes()
      [%Airplane{}, ...]

  """
  def list_airplanes do
    Repo.all(Airplane)
  end

  @doc """
  Gets a single airplane.

  Raises `Ecto.NoResultsError` if the Airplane does not exist.

  ## Examples

      iex> get_airplane!(123)
      %Airplane{}

      iex> get_airplane!(456)
      ** (Ecto.NoResultsError)

  """
  def get_airplane!(id), do: Repo.get!(Airplane, id)

  @doc """
  Gets a single airplane by tail number.

  Returns `{:ok, airplane}` if found, `{:error, :not_found}` if not found.

  ## Examples

      iex> get_airplane_by_tail_number("N12345")
      {:ok, %Airplane{}}

      iex> get_airplane_by_tail_number("INVALID")
      {:error, :not_found}

  """
  def get_airplane_by_tail_number(tail_number) when is_binary(tail_number) do
    case Repo.get_by(Airplane, tail_number: tail_number) do
      nil -> {:error, :not_found}
      airplane -> {:ok, airplane}
    end
  end

  @doc """
  Creates a airplane.

  ## Examples

      iex> create_airplane(%{field: value})
      {:ok, %Airplane{}}

      iex> create_airplane(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_airplane(attrs \\ %{}) do
    %Airplane{}
    |> Airplane.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a airplane.

  ## Examples

      iex> update_airplane(airplane, %{field: new_value})
      {:ok, %Airplane{}}

      iex> update_airplane(airplane, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_airplane(%Airplane{} = airplane, attrs) do
    airplane
    |> Airplane.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a airplane.

  ## Examples

      iex> delete_airplane(airplane)
      {:ok, %Airplane{}}

      iex> delete_airplane(airplane)
      {:error, %Ecto.Changeset{}}

  """
  def delete_airplane(%Airplane{} = airplane) do
    Repo.delete(airplane)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking airplane changes.

  ## Examples

      iex> change_airplane(airplane)
      %Ecto.Changeset{data: %Airplane{}}

  """
  def change_airplane(%Airplane{} = airplane, attrs \\ %{}) do
    Airplane.changeset(airplane, attrs)
  end

  @doc """
  Associates a pilot with an airplane.

  ## Examples

      iex> add_pilot_to_airplane(airplane, pilot)
      {:ok, %Airplane{}}

  """
  def add_pilot_to_airplane(%Airplane{} = airplane, %FlightLog.Accounts.Pilot{} = pilot) do
    airplane = Repo.preload(airplane, :pilots)

    airplane
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:pilots, [pilot | airplane.pilots])
    |> Repo.update()
  end

  @doc """
  Removes a pilot from an airplane.

  ## Examples

      iex> remove_pilot_from_airplane(airplane, pilot)
      {:ok, %Airplane{}}

  """
  def remove_pilot_from_airplane(%Airplane{} = airplane, %FlightLog.Accounts.Pilot{} = pilot) do
    airplane = Repo.preload(airplane, :pilots)

    airplane
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:pilots, Enum.reject(airplane.pilots, &(&1.id == pilot.id)))
    |> Repo.update()
  end

  @doc """
  Lists all airplanes for a given pilot.

  ## Examples

      iex> list_airplanes_for_pilot(pilot)
      [%Airplane{}, ...]

  """
  def list_airplanes_for_pilot(%FlightLog.Accounts.Pilot{} = pilot) do
    pilot
    |> Repo.preload(:airplanes)
    |> Map.get(:airplanes)
  end
end
