defmodule FlightLogWeb.FlightLive.LogFlight do
  use FlightLogWeb, :live_view

  alias FlightLog.Flights
  alias FlightLog.Flights.Flight
  alias FlightLog.Airplanes

  @impl true
  def mount(%{"tail_number" => tail_number}, _session, socket) do
    case Airplanes.get_airplane_by_tail_number(tail_number) do
      {:ok, airplane} ->
        {:ok,
         socket
         |> assign(:airplane, airplane)
         |> assign(:tail_number, tail_number)
         |> assign(:page_title, "Log Flight - #{airplane.tail_number}")
         |> assign(:flight, %Flight{airplane_id: airplane.id, pilot_id: socket.assigns.current_pilot.id})
         |> assign_form()}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Airplane with tail number '#{tail_number}' not found.")
         |> redirect(to: ~p"/flights")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header>
        Log Flight - {@airplane.tail_number}
        <:subtitle>
          Flying {@airplane.make} {@airplane.model} ({@airplane.tail_number})
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="flight-form"
        phx-submit="save"
        phx-change="validate"
      >
        <input type="hidden" name="flight[pilot_id]" value={@current_pilot.id} />
        <input type="hidden" name="flight[airplane_id]" value={@airplane.id} />

        <.input field={@form[:hobbs_reading]} type="number" label="Hobbs reading" step="any" required />
        <.input field={@form[:flight_date]} type="date" label="Flight date" required />

        <:actions>
          <.button phx-disable-with="Saving...">Save Flight</.button>
        </:actions>
      </.simple_form>

      <.back navigate={~p"/flights"}>Back to flights</.back>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"flight" => flight_params}, socket) do
    # Add the pilot_id and airplane_id to the params for validation
    flight_params =
      flight_params
      |> Map.put("pilot_id", to_string(socket.assigns.current_pilot.id))
      |> Map.put("airplane_id", to_string(socket.assigns.airplane.id))

    changeset = Flights.change_flight(socket.assigns.flight, flight_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("save", %{"flight" => flight_params}, socket) do
    # Add the pilot_id and airplane_id to the params for creation
    flight_params =
      flight_params
      |> Map.put("pilot_id", socket.assigns.current_pilot.id)
      |> Map.put("airplane_id", socket.assigns.airplane.id)

    case Flights.create_flight(flight_params) do
      {:ok, _flight} ->
        {:noreply,
         socket
         |> put_flash(:info, "Flight logged successfully!")
         |> redirect(to: ~p"/flights")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp assign_form(socket) do
    changeset = Flights.change_flight(socket.assigns.flight)
    assign(socket, form: to_form(changeset))
  end
end
