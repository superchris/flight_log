defmodule FlightLogWeb.PilotMagicLinkLive do
  use FlightLogWeb, :live_view

  alias FlightLog.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Log in with email
        <:subtitle>We'll send a magic link to your inbox</:subtitle>
      </.header>

      <.simple_form for={@form} id="magic_link_form" phx-submit="send_email">
        <.input field={@form[:email]} type="email" placeholder="Email" required />
        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Send magic link
          </.button>
        </:actions>
      </.simple_form>
      <p class="text-center text-sm mt-4">
        <.link href={~p"/pilots/log_in"}>Log in with password</.link>
        | <.link href={~p"/pilots/register"}>Register</.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "pilot"))}
  end

  def handle_event("send_email", %{"pilot" => %{"email" => email}}, socket) do
    if pilot = Accounts.get_pilot_by_email(email) do
      Accounts.deliver_pilot_magic_link_instructions(
        pilot,
        &url(~p"/pilots/log_in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive a link to log in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/pilots/log_in")}
  end
end
