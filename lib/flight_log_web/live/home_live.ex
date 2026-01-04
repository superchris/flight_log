defmodule FlightLogWeb.HomeLive do
  use FlightLogWeb, :live_view

  alias FlightLog.Airplanes

  @impl true
  def mount(_params, _session, socket) do
    case Airplanes.get_first_airplane_for_pilot(socket.assigns.current_pilot) do
      {:ok, airplane} ->
        {:ok, push_navigate(socket, to: ~p"/flights/monthly/#{airplane.tail_number}")}

      {:error, :no_airplanes} ->
        {:ok, push_navigate(socket, to: ~p"/airplanes")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>Redirecting...</div>
    """
  end
end
