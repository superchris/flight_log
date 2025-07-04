defmodule FlightLogWeb.PilotForgotPasswordLive do
  use FlightLogWeb, :live_view

  alias FlightLog.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Forgot your password?
        <:subtitle>We'll send a password reset link to your inbox</:subtitle>
      </.header>

      <.simple_form for={@form} id="reset_password_form" phx-submit="send_email">
        <.input field={@form[:email]} type="email" placeholder="Email" required />
        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Send password reset instructions
          </.button>
        </:actions>
      </.simple_form>
      <p class="text-center text-sm mt-4">
        <.link href={~p"/pilots/register"}>Register</.link>
        | <.link href={~p"/pilots/log_in"}>Log in</.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "pilot"))}
  end

  def handle_event("send_email", %{"pilot" => %{"email" => email}}, socket) do
    if pilot = Accounts.get_pilot_by_email(email) do
      Accounts.deliver_pilot_reset_password_instructions(
        pilot,
        &url(~p"/pilots/reset_password/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
