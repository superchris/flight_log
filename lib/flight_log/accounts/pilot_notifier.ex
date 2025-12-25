defmodule FlightLog.Accounts.PilotNotifier do
  import Swoosh.Email

  alias FlightLog.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    from_email = System.get_env("FROM_EMAIL") || "noreply@example.com"
    from_name = System.get_env("FROM_NAME") || "FlightLog"

    email =
      new()
      |> to(recipient)
      |> from({from_name, from_email})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(pilot, url) do
    deliver(pilot.email, "Confirmation instructions", """

    ==============================

    Hi #{pilot.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a pilot password.
  """
  def deliver_reset_password_instructions(pilot, url) do
    deliver(pilot.email, "Reset password instructions", """

    ==============================

    Hi #{pilot.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a pilot email.
  """
  def deliver_update_email_instructions(pilot, url) do
    deliver(pilot.email, "Update email instructions", """

    ==============================

    Hi #{pilot.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver magic link login instructions.
  """
  def deliver_magic_link_instructions(pilot, url) do
    deliver(pilot.email, "Log in to FlightLog", """

    ==============================

    Hi #{pilot.email},

    You can log in to your account by visiting the URL below:

    #{url}

    This link will expire in 15 minutes.

    If you didn't request this link, please ignore this email.

    ==============================
    """)
  end
end
