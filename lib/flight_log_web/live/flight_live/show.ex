defmodule FlightLogWeb.FlightLive.Show do
  use FlightLogWeb, :live_view

  alias FlightLog.Flights

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:flight, Flights.get_flight!(id))}
  end

  defp page_title(:show), do: "Show Flight"
  defp page_title(:edit), do: "Edit Flight"
end
