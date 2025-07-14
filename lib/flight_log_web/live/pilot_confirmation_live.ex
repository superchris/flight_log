defmodule FlightLogWeb.PilotConfirmationLive do
  use FlightLogWeb, :live_view

  alias FlightLog.Accounts

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Confirm Account</.header>

      <.simple_form for={@form} id="confirmation_form" phx-submit="confirm_account">
        <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <:actions>
          <.button phx-disable-with="Confirming..." class="w-full">Confirm my account</.button>
        </:actions>
      </.simple_form>

      <p class="text-center mt-4">
        <.link href={~p"/pilots/register"}>Register</.link>
        | <.link href={~p"/pilots/log_in"}>Log in</.link>
      </p>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    form = to_form(%{"token" => token}, as: "pilot")
    {:ok, assign(socket, form: form), temporary_assigns: [form: nil]}
  end

  # Do not log in the pilot after confirmation to avoid a
  # leaked token giving the pilot access to the account.
  def handle_event("confirm_account", %{"pilot" => %{"token" => token}}, socket) do
    case Accounts.confirm_pilot(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Pilot confirmed successfully.")
         |> redirect(to: ~p"/")}

      :error ->
        # If there is a current pilot and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the pilot themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_pilot: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            {:noreply, redirect(socket, to: ~p"/")}

          %{} ->
            {:noreply,
             socket
             |> put_flash(:error, "Pilot confirmation link is invalid or it has expired.")
             |> redirect(to: ~p"/pilots/log_in")}
        end
    end
  end
end
