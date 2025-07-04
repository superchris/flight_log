defmodule FlightLogWeb.PilotSessionController do
  use FlightLogWeb, :controller

  alias FlightLog.Accounts
  alias FlightLogWeb.PilotAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:pilot_return_to, ~p"/pilots/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"pilot" => pilot_params}, info) do
    %{"email" => email, "password" => password} = pilot_params

    if pilot = Accounts.get_pilot_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> PilotAuth.log_in_pilot(pilot, pilot_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/pilots/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> PilotAuth.log_out_pilot()
  end
end
