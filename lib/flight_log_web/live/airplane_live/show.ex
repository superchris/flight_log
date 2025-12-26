defmodule FlightLogWeb.AirplaneLive.Show do
  use FlightLogWeb, :live_view

  alias FlightLog.Airplanes
  alias FlightLog.Accounts
  alias FlightLog.Costs
  alias FlightLog.Costs.Cost
  alias FlightLog.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    airplane = Airplanes.get_airplane!(id) |> Repo.preload(:pilots)
    costs = Costs.list_costs_for_airplane(airplane.id)
    all_pilots = Accounts.list_pilots()
    available_pilots = Enum.reject(all_pilots, fn p -> p.id in Enum.map(airplane.pilots, & &1.id) end)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:airplane, airplane)
     |> assign(:costs, costs)
     |> assign(:available_pilots, available_pilots)
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

  @impl true
  def handle_event("add_pilot", %{"pilot_id" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("add_pilot", %{"pilot_id" => pilot_id}, socket) do
    pilot = Accounts.get_pilot!(pilot_id)
    {:ok, airplane} = Airplanes.add_pilot_to_airplane(socket.assigns.airplane, pilot)
    airplane = Repo.preload(airplane, :pilots, force: true)
    all_pilots = Accounts.list_pilots()
    available_pilots = Enum.reject(all_pilots, fn p -> p.id in Enum.map(airplane.pilots, & &1.id) end)

    {:noreply,
     socket
     |> assign(:airplane, airplane)
     |> assign(:available_pilots, available_pilots)}
  end

  @impl true
  def handle_event("remove_pilot", %{"pilot_id" => pilot_id}, socket) do
    pilot = Accounts.get_pilot!(pilot_id)
    {:ok, airplane} = Airplanes.remove_pilot_from_airplane(socket.assigns.airplane, pilot)
    airplane = Repo.preload(airplane, :pilots, force: true)
    all_pilots = Accounts.list_pilots()
    available_pilots = Enum.reject(all_pilots, fn p -> p.id in Enum.map(airplane.pilots, & &1.id) end)

    {:noreply,
     socket
     |> assign(:airplane, airplane)
     |> assign(:available_pilots, available_pilots)}
  end

  defp page_title(:show), do: "Show Airplane"
  defp page_title(:edit), do: "Edit Airplane"
  defp page_title(:new_cost), do: "New Cost"
  defp page_title(:edit_cost), do: "Edit Cost"
end
