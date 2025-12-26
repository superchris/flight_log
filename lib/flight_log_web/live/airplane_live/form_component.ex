defmodule FlightLogWeb.AirplaneLive.FormComponent do
  use FlightLogWeb, :live_component

  alias FlightLog.Airplanes

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage airplane records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="airplane-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:tail_number]} type="text" label="Tail number" />
        <.input field={@form[:initial_hobbs_reading]} type="number" label="Initial hobbs reading" step="any" />
        <.input field={@form[:model]} type="text" label="Model" />
        <.input field={@form[:make]} type="text" label="Make" />
        <.input field={@form[:year]} type="number" label="Year" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Airplane</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{airplane: airplane} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Airplanes.change_airplane(airplane))
     end)}
  end

  @impl true
  def handle_event("validate", %{"airplane" => airplane_params}, socket) do
    changeset = Airplanes.change_airplane(socket.assigns.airplane, airplane_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"airplane" => airplane_params}, socket) do
    save_airplane(socket, socket.assigns.action, airplane_params)
  end

  defp save_airplane(socket, :edit, airplane_params) do
    case Airplanes.update_airplane(socket.assigns.airplane, airplane_params) do
      {:ok, airplane} ->
        notify_parent({:saved, airplane})

        {:noreply,
         socket
         |> put_flash(:info, "Airplane updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_airplane(socket, :new, airplane_params) do
    with {:ok, airplane} <- Airplanes.create_airplane(airplane_params),
         {:ok, airplane} <- Airplanes.add_pilot_to_airplane(airplane, socket.assigns.current_pilot) do
      notify_parent({:saved, airplane})

      {:noreply,
       socket
       |> put_flash(:info, "Airplane created successfully")
       |> push_patch(to: socket.assigns.patch)}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
