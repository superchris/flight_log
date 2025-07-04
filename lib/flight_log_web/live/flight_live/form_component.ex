defmodule FlightLogWeb.FlightLive.FormComponent do
  use FlightLogWeb, :live_component

  alias FlightLog.Flights
  alias FlightLog.Accounts
  alias FlightLog.Airplanes

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage flight records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="flight-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:pilot_id]}
          type="select"
          label="Pilot"
          options={@pilot_options}
          prompt="Select a pilot"
        />
        <.input
          field={@form[:airplane_id]}
          type="select"
          label="Airplane"
          options={@airplane_options}
          prompt="Select an airplane"
        />
        <.input field={@form[:hobbs_reading]} type="number" label="Hobbs reading" step="any" />
        <.input field={@form[:flight_date]} type="date" label="Flight date" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Flight</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{flight: flight} = assigns, socket) do
    pilots = Accounts.list_pilots()
    airplanes = Airplanes.list_airplanes()

    pilot_options = Enum.map(pilots, &{&1.email, &1.id})
    airplane_options = Enum.map(airplanes, &{"#{&1.tail_number} (#{&1.make} #{&1.model})", &1.id})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:pilot_options, pilot_options)
     |> assign(:airplane_options, airplane_options)
     |> assign_new(:form, fn ->
       to_form(Flights.change_flight(flight))
     end)}
  end

  @impl true
  def handle_event("validate", %{"flight" => flight_params}, socket) do
    changeset = Flights.change_flight(socket.assigns.flight, flight_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"flight" => flight_params}, socket) do
    save_flight(socket, socket.assigns.action, flight_params)
  end

  defp save_flight(socket, :edit, flight_params) do
    case Flights.update_flight(socket.assigns.flight, flight_params) do
      {:ok, flight} ->
        notify_parent({:saved, flight})

        {:noreply,
         socket
         |> put_flash(:info, "Flight updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_flight(socket, :new, flight_params) do
    case Flights.create_flight(flight_params) do
      {:ok, flight} ->
        notify_parent({:saved, flight})

        {:noreply,
         socket
         |> put_flash(:info, "Flight created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
