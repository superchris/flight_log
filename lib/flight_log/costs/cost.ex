defmodule FlightLog.Costs.Cost do
  use Ecto.Schema
  import Ecto.Changeset

  schema "costs" do
    field :cost_type, Ecto.Enum, values: [:monthly, :hourly, :one_time]
    field :amount, :decimal
    field :description, :string
    field :effective_date, :date

    belongs_to :airplane, FlightLog.Airplanes.Airplane

    timestamps(type: :utc_datetime)
  end

  @cost_types ~w[monthly hourly one_time]a

  @doc false
  def changeset(cost, attrs) do
    cost
    |> cast(attrs, [:airplane_id, :cost_type, :amount, :description, :effective_date])
    |> validate_required([:airplane_id, :cost_type, :amount])
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:airplane_id)
  end

  def cost_types, do: @cost_types
end
