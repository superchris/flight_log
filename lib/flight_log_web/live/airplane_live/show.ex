defmodule FlightLogWeb.AirplaneLive.Show do
  use FlightLogWeb, :live_view

  alias FlightLog.Airplanes
  alias FlightLog.Costs
  alias FlightLog.Costs.Cost

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    airplane = Airplanes.get_airplane!(id)
    costs = Costs.list_costs_for_airplane(airplane.id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:airplane, airplane)
     |> assign(:costs, costs)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    socket
  end

  defp apply_action(socket, :edit, _params) do
    socket
  end

  defp apply_action(socket, :new_cost, _params) do
    socket
    |> assign(:page_title, "New Cost")
    |> assign(:cost, %Cost{})
  end

  defp apply_action(socket, :edit_cost, %{"cost_id" => cost_id}) do
    socket
    |> assign(:page_title, "Edit Cost")
    |> assign(:cost, Costs.get_cost!(cost_id))
  end

  @impl true
  def handle_info({FlightLogWeb.AirplaneLive.CostFormComponent, {:saved, _cost}}, socket) do
    costs = Costs.list_costs_for_airplane(socket.assigns.airplane.id)
    {:noreply, assign(socket, costs: costs)}
  end

  @impl true
  def handle_info({FlightLogWeb.AirplaneLive.FormComponent, {:saved, airplane}}, socket) do
    {:noreply, assign(socket, airplane: airplane)}
  end

  @impl true
  def handle_event("delete_cost", %{"id" => id}, socket) do
    cost = Costs.get_cost!(id)
    {:ok, _} = Costs.delete_cost(cost)

    costs = Costs.list_costs_for_airplane(socket.assigns.airplane.id)
    {:noreply, assign(socket, costs: costs)}
  end

  defp page_title(:show), do: "Show Airplane"
  defp page_title(:edit), do: "Edit Airplane"
  defp page_title(:new_cost), do: "New Cost"
  defp page_title(:edit_cost), do: "Edit Cost"
end
