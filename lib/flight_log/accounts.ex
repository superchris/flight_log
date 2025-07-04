defmodule FlightLog.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias FlightLog.Repo

  alias FlightLog.Accounts.{Pilot, PilotToken, PilotNotifier}

  ## Database getters

  @doc """
  Returns the list of pilots.

  ## Examples

      iex> list_pilots()
      [%Pilot{}, ...]

  """
  def list_pilots do
    Repo.all(Pilot)
  end

  @doc """
  Gets a pilot by email.

  ## Examples

      iex> get_pilot_by_email("foo@example.com")
      %Pilot{}

      iex> get_pilot_by_email("unknown@example.com")
      nil

  """
  def get_pilot_by_email(email) when is_binary(email) do
    Repo.get_by(Pilot, email: email)
  end

  @doc """
  Gets a pilot by email and password.

  ## Examples

      iex> get_pilot_by_email_and_password("foo@example.com", "correct_password")
      %Pilot{}

      iex> get_pilot_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_pilot_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    pilot = Repo.get_by(Pilot, email: email)
    if Pilot.valid_password?(pilot, password), do: pilot
  end

  @doc """
  Gets a single pilot.

  Raises `Ecto.NoResultsError` if the Pilot does not exist.

  ## Examples

      iex> get_pilot!(123)
      %Pilot{}

      iex> get_pilot!(456)
      ** (Ecto.NoResultsError)

  """
  def get_pilot!(id), do: Repo.get!(Pilot, id)

  ## Pilot registration

  @doc """
  Registers a pilot.

  ## Examples

      iex> register_pilot(%{field: value})
      {:ok, %Pilot{}}

      iex> register_pilot(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_pilot(attrs) do
    %Pilot{}
    |> Pilot.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking pilot changes.

  ## Examples

      iex> change_pilot_registration(pilot)
      %Ecto.Changeset{data: %Pilot{}}

  """
  def change_pilot_registration(%Pilot{} = pilot, attrs \\ %{}) do
    Pilot.registration_changeset(pilot, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the pilot email.

  ## Examples

      iex> change_pilot_email(pilot)
      %Ecto.Changeset{data: %Pilot{}}

  """
  def change_pilot_email(pilot, attrs \\ %{}) do
    Pilot.email_changeset(pilot, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_pilot_email(pilot, "valid password", %{email: ...})
      {:ok, %Pilot{}}

      iex> apply_pilot_email(pilot, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_pilot_email(pilot, password, attrs) do
    pilot
    |> Pilot.email_changeset(attrs)
    |> Pilot.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the pilot email using the given token.

  If the token matches, the pilot email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_pilot_email(pilot, token) do
    context = "change:#{pilot.email}"

    with {:ok, query} <- PilotToken.verify_change_email_token_query(token, context),
         %PilotToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(pilot_email_multi(pilot, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp pilot_email_multi(pilot, email, context) do
    changeset =
      pilot
      |> Pilot.email_changeset(%{email: email})
      |> Pilot.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:pilot, changeset)
    |> Ecto.Multi.delete_all(:tokens, PilotToken.by_pilot_and_contexts_query(pilot, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given pilot.

  ## Examples

      iex> deliver_pilot_update_email_instructions(pilot, current_email, &url(~p"/pilots/settings/confirm_email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_pilot_update_email_instructions(%Pilot{} = pilot, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, pilot_token} = PilotToken.build_email_token(pilot, "change:#{current_email}")

    Repo.insert!(pilot_token)
    PilotNotifier.deliver_update_email_instructions(pilot, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the pilot password.

  ## Examples

      iex> change_pilot_password(pilot)
      %Ecto.Changeset{data: %Pilot{}}

  """
  def change_pilot_password(pilot, attrs \\ %{}) do
    Pilot.password_changeset(pilot, attrs, hash_password: false)
  end

  @doc """
  Updates the pilot password.

  ## Examples

      iex> update_pilot_password(pilot, "valid password", %{password: ...})
      {:ok, %Pilot{}}

      iex> update_pilot_password(pilot, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_pilot_password(pilot, password, attrs) do
    changeset =
      pilot
      |> Pilot.password_changeset(attrs)
      |> Pilot.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:pilot, changeset)
    |> Ecto.Multi.delete_all(:tokens, PilotToken.by_pilot_and_contexts_query(pilot, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{pilot: pilot}} -> {:ok, pilot}
      {:error, :pilot, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_pilot_session_token(pilot) do
    {token, pilot_token} = PilotToken.build_session_token(pilot)
    Repo.insert!(pilot_token)
    token
  end

  @doc """
  Gets the pilot with the given signed token.
  """
  def get_pilot_by_session_token(token) do
    {:ok, query} = PilotToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_pilot_session_token(token) do
    Repo.delete_all(PilotToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given pilot.

  ## Examples

      iex> deliver_pilot_confirmation_instructions(pilot, &url(~p"/pilots/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_pilot_confirmation_instructions(confirmed_pilot, &url(~p"/pilots/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_pilot_confirmation_instructions(%Pilot{} = pilot, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if pilot.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, pilot_token} = PilotToken.build_email_token(pilot, "confirm")
      Repo.insert!(pilot_token)
      PilotNotifier.deliver_confirmation_instructions(pilot, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a pilot by the given token.

  If the token matches, the pilot account is marked as confirmed
  and the token is deleted.
  """
  def confirm_pilot(token) do
    with {:ok, query} <- PilotToken.verify_email_token_query(token, "confirm"),
         %Pilot{} = pilot <- Repo.one(query),
         {:ok, %{pilot: pilot}} <- Repo.transaction(confirm_pilot_multi(pilot)) do
      {:ok, pilot}
    else
      _ -> :error
    end
  end

  defp confirm_pilot_multi(pilot) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:pilot, Pilot.confirm_changeset(pilot))
    |> Ecto.Multi.delete_all(:tokens, PilotToken.by_pilot_and_contexts_query(pilot, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given pilot.

  ## Examples

      iex> deliver_pilot_reset_password_instructions(pilot, &url(~p"/pilots/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_pilot_reset_password_instructions(%Pilot{} = pilot, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, pilot_token} = PilotToken.build_email_token(pilot, "reset_password")
    Repo.insert!(pilot_token)
    PilotNotifier.deliver_reset_password_instructions(pilot, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the pilot by reset password token.

  ## Examples

      iex> get_pilot_by_reset_password_token("validtoken")
      %Pilot{}

      iex> get_pilot_by_reset_password_token("invalidtoken")
      nil

  """
  def get_pilot_by_reset_password_token(token) do
    with {:ok, query} <- PilotToken.verify_email_token_query(token, "reset_password"),
         %Pilot{} = pilot <- Repo.one(query) do
      pilot
    else
      _ -> nil
    end
  end

  @doc """
  Resets the pilot password.

  ## Examples

      iex> reset_pilot_password(pilot, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %Pilot{}}

      iex> reset_pilot_password(pilot, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_pilot_password(pilot, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:pilot, Pilot.password_changeset(pilot, attrs))
    |> Ecto.Multi.delete_all(:tokens, PilotToken.by_pilot_and_contexts_query(pilot, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{pilot: pilot}} -> {:ok, pilot}
      {:error, :pilot, changeset, _} -> {:error, changeset}
    end
  end
end
