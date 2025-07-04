defmodule FlightLogWeb.AirplaneLive.Show do
  use FlightLogWeb, :live_view

  alias FlightLog.Airplanes

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:airplane, Airplanes.get_airplane!(id))}
  end

  defp page_title(:show), do: "Show Airplane"
  defp page_title(:edit), do: "Edit Airplane"
end
