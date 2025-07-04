defmodule FlightLogWeb.FlightLive.Index do
  use FlightLogWeb, :live_view

  alias FlightLog.Flights
  alias FlightLog.Flights.Flight

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :flights, Flights.list_flights())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Flight")
    |> assign(:flight, Flights.get_flight!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Flight")
    |> assign(:flight, %Flight{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Flights")
    |> assign(:flight, nil)
  end

  @impl true
  def handle_info({FlightLogWeb.FlightLive.FormComponent, {:saved, flight}}, socket) do
    {:noreply, stream_insert(socket, :flights, flight)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    flight = Flights.get_flight!(id)
    {:ok, _} = Flights.delete_flight(flight)

    {:noreply, stream_delete(socket, :flights, flight)}
  end
end
