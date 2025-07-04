defmodule FlightLogWeb.AirplaneLive.CostFormComponent do
  use FlightLogWeb, :live_component

  alias FlightLog.Costs

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Manage costs for this airplane</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="cost-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:cost_type]}
          type="select"
          label="Cost Type"
          options={[
            {"Monthly", :monthly},
            {"Hourly", :hourly},
            {"One Time", :one_time}
          ]}
          prompt="Select cost type"
        />
        <.input field={@form[:amount]} type="number" label="Amount ($)" step="0.01" />
        <.input field={@form[:description]} type="text" label="Description (optional)" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Cost</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{cost: cost} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Costs.change_cost(cost))
     end)}
  end

  @impl true
  def handle_event("validate", %{"cost" => cost_params}, socket) do
    changeset = Costs.change_cost(socket.assigns.cost, cost_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"cost" => cost_params}, socket) do
    action = case socket.assigns.action do
      :new_cost -> :new
      :edit_cost -> :edit
      action -> action
    end
    save_cost(socket, action, cost_params)
  end

  defp save_cost(socket, :edit, cost_params) do
    case Costs.update_cost(socket.assigns.cost, cost_params) do
      {:ok, cost} ->
        notify_parent({:saved, cost})

        {:noreply,
         socket
         |> put_flash(:info, "Cost updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_cost(socket, :new, cost_params) do
    cost_params = Map.put(cost_params, "airplane_id", socket.assigns.airplane_id)

    case Costs.create_cost(cost_params) do
      {:ok, cost} ->
        notify_parent({:saved, cost})

        {:noreply,
         socket
         |> put_flash(:info, "Cost created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
