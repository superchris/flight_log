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
end
