defmodule FlightLogWeb.AirplaneLive.Index do
  use FlightLogWeb, :live_view

  alias FlightLog.Airplanes
  alias FlightLog.Airplanes.Airplane

  @impl true
  def mount(_params, _session, socket) do
    airplanes = Airplanes.list_airplanes_for_pilot(socket.assigns.current_pilot)
    {:ok, stream(socket, :airplanes, airplanes)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case Airplanes.get_airplane_for_pilot(id, socket.assigns.current_pilot) do
      {:ok, airplane} ->
        socket
        |> assign(:page_title, "Edit Airplane")
        |> assign(:airplane, airplane)

      {:error, _} ->
        socket
        |> put_flash(:error, "You are not authorized to edit this airplane")
        |> push_navigate(to: ~p"/airplanes")
    end
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Airplane")
    |> assign(:airplane, %Airplane{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Airplanes")
    |> assign(:airplane, nil)
  end

  @impl true
  def handle_info({FlightLogWeb.AirplaneLive.FormComponent, {:saved, airplane}}, socket) do
    {:noreply, stream_insert(socket, :airplanes, airplane)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Airplanes.get_airplane_for_pilot(id, socket.assigns.current_pilot) do
      {:ok, airplane} ->
        {:ok, _} = Airplanes.delete_airplane(airplane)
        {:noreply, stream_delete(socket, :airplanes, airplane)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to delete this airplane")}
    end
  end
end
