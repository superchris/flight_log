defmodule FlightLog.AccountsTest do
  use FlightLog.DataCase

  alias FlightLog.Accounts

  import FlightLog.AccountsFixtures
  alias FlightLog.Accounts.{Pilot, PilotToken}

  describe "get_pilot_by_email/1" do
    test "does not return the pilot if the email does not exist" do
      refute Accounts.get_pilot_by_email("unknown@example.com")
    end

    test "returns the pilot if the email exists" do
      %{id: id} = pilot = pilot_fixture()
      assert %Pilot{id: ^id} = Accounts.get_pilot_by_email(pilot.email)
    end
  end

  describe "get_pilot_by_email_and_password/2" do
    test "does not return the pilot if the email does not exist" do
      refute Accounts.get_pilot_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the pilot if the password is not valid" do
      pilot = pilot_fixture()
      refute Accounts.get_pilot_by_email_and_password(pilot.email, "invalid")
    end

    test "returns the pilot if the email and password are valid" do
      %{id: id} = pilot = pilot_fixture()

      assert %Pilot{id: ^id} =
               Accounts.get_pilot_by_email_and_password(pilot.email, valid_pilot_password())
    end
  end

  describe "get_pilot!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_pilot!(-1)
      end
    end

    test "returns the pilot with the given id" do
      %{id: id} = pilot = pilot_fixture()
      assert %Pilot{id: ^id} = Accounts.get_pilot!(pilot.id)
    end
  end

  describe "register_pilot/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_pilot(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"],
               first_name: ["can't be blank"],
               last_name: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_pilot(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_pilot(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = pilot_fixture()
      {:error, changeset} = Accounts.register_pilot(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_pilot(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers pilots with a hashed password" do
      email = unique_pilot_email()
      {:ok, pilot} = Accounts.register_pilot(valid_pilot_attributes(email: email))
      assert pilot.email == email
      assert is_binary(pilot.hashed_password)
      assert is_nil(pilot.confirmed_at)
      assert is_nil(pilot.password)
    end
  end

  describe "change_pilot_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_pilot_registration(%Pilot{})
      assert changeset.required == [:password, :email, :first_name, :last_name]
    end

    test "allows fields to be set" do
      email = unique_pilot_email()
      password = valid_pilot_password()

      changeset =
        Accounts.change_pilot_registration(
          %Pilot{},
          valid_pilot_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_pilot_email/2" do
    test "returns a pilot changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_pilot_email(%Pilot{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_pilot_email/3" do
    setup do
      %{pilot: pilot_fixture()}
    end

    test "requires email to change", %{pilot: pilot} do
      {:error, changeset} = Accounts.apply_pilot_email(pilot, valid_pilot_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{pilot: pilot} do
      {:error, changeset} =
        Accounts.apply_pilot_email(pilot, valid_pilot_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{pilot: pilot} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_pilot_email(pilot, valid_pilot_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{pilot: pilot} do
      %{email: email} = pilot_fixture()
      password = valid_pilot_password()

      {:error, changeset} = Accounts.apply_pilot_email(pilot, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{pilot: pilot} do
      {:error, changeset} =
        Accounts.apply_pilot_email(pilot, "invalid", %{email: unique_pilot_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{pilot: pilot} do
      email = unique_pilot_email()
      {:ok, pilot} = Accounts.apply_pilot_email(pilot, valid_pilot_password(), %{email: email})
      assert pilot.email == email
      assert Accounts.get_pilot!(pilot.id).email != email
    end
  end

  describe "deliver_pilot_update_email_instructions/3" do
    setup do
      %{pilot: pilot_fixture()}
    end

    test "sends token through notification", %{pilot: pilot} do
      token =
        extract_pilot_token(fn url ->
          Accounts.deliver_pilot_update_email_instructions(pilot, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert pilot_token = Repo.get_by(PilotToken, token: :crypto.hash(:sha256, token))
      assert pilot_token.pilot_id == pilot.id
      assert pilot_token.sent_to == pilot.email
      assert pilot_token.context == "change:current@example.com"
    end
  end

  describe "update_pilot_email/2" do
    setup do
      pilot = pilot_fixture()
      email = unique_pilot_email()

      token =
        extract_pilot_token(fn url ->
          Accounts.deliver_pilot_update_email_instructions(%{pilot | email: email}, pilot.email, url)
        end)

      %{pilot: pilot, token: token, email: email}
    end

    test "updates the email with a valid token", %{pilot: pilot, token: token, email: email} do
      assert Accounts.update_pilot_email(pilot, token) == :ok
      changed_pilot = Repo.get!(Pilot, pilot.id)
      assert changed_pilot.email != pilot.email
      assert changed_pilot.email == email
      assert changed_pilot.confirmed_at
      assert changed_pilot.confirmed_at != pilot.confirmed_at
      refute Repo.get_by(PilotToken, pilot_id: pilot.id)
    end

    test "does not update email with invalid token", %{pilot: pilot} do
      assert Accounts.update_pilot_email(pilot, "oops") == :error
      assert Repo.get!(Pilot, pilot.id).email == pilot.email
      assert Repo.get_by(PilotToken, pilot_id: pilot.id)
    end

    test "does not update email if pilot email changed", %{pilot: pilot, token: token} do
      assert Accounts.update_pilot_email(%{pilot | email: "current@example.com"}, token) == :error
      assert Repo.get!(Pilot, pilot.id).email == pilot.email
      assert Repo.get_by(PilotToken, pilot_id: pilot.id)
    end

    test "does not update email if token expired", %{pilot: pilot, token: token} do
      {1, nil} = Repo.update_all(PilotToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_pilot_email(pilot, token) == :error
      assert Repo.get!(Pilot, pilot.id).email == pilot.email
      assert Repo.get_by(PilotToken, pilot_id: pilot.id)
    end
  end

  describe "change_pilot_password/2" do
    test "returns a pilot changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_pilot_password(%Pilot{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_pilot_password(%Pilot{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_pilot_password/3" do
    setup do
      %{pilot: pilot_fixture()}
    end

    test "validates password", %{pilot: pilot} do
      {:error, changeset} =
        Accounts.update_pilot_password(pilot, valid_pilot_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{pilot: pilot} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_pilot_password(pilot, valid_pilot_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{pilot: pilot} do
      {:error, changeset} =
        Accounts.update_pilot_password(pilot, "invalid", %{password: valid_pilot_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{pilot: pilot} do
      {:ok, pilot} =
        Accounts.update_pilot_password(pilot, valid_pilot_password(), %{
          password: "new valid password"
        })

      assert is_nil(pilot.password)
      assert Accounts.get_pilot_by_email_and_password(pilot.email, "new valid password")
    end

    test "deletes all tokens for the given pilot", %{pilot: pilot} do
      _ = Accounts.generate_pilot_session_token(pilot)

      {:ok, _} =
        Accounts.update_pilot_password(pilot, valid_pilot_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(PilotToken, pilot_id: pilot.id)
    end
  end

  describe "generate_pilot_session_token/1" do
    setup do
      %{pilot: pilot_fixture()}
    end

    test "generates a token", %{pilot: pilot} do
      token = Accounts.generate_pilot_session_token(pilot)
      assert pilot_token = Repo.get_by(PilotToken, token: token)
      assert pilot_token.context == "session"

      # Creating the same token for another pilot should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%PilotToken{
          token: pilot_token.token,
          pilot_id: pilot_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_pilot_by_session_token/1" do
    setup do
      pilot = pilot_fixture()
      token = Accounts.generate_pilot_session_token(pilot)
      %{pilot: pilot, token: token}
    end

    test "returns pilot by token", %{pilot: pilot, token: token} do
      assert session_pilot = Accounts.get_pilot_by_session_token(token)
      assert session_pilot.id == pilot.id
    end

    test "does not return pilot for invalid token" do
      refute Accounts.get_pilot_by_session_token("oops")
    end

    test "does not return pilot for expired token", %{token: token} do
      {1, nil} = Repo.update_all(PilotToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_pilot_by_session_token(token)
    end
  end

  describe "delete_pilot_session_token/1" do
    test "deletes the token" do
      pilot = pilot_fixture()
      token = Accounts.generate_pilot_session_token(pilot)
      assert Accounts.delete_pilot_session_token(token) == :ok
      refute Accounts.get_pilot_by_session_token(token)
    end
  end

  describe "deliver_pilot_confirmation_instructions/2" do
    setup do
      %{pilot: pilot_fixture()}
    end

    test "sends token through notification", %{pilot: pilot} do
      token =
        extract_pilot_token(fn url ->
          Accounts.deliver_pilot_confirmation_instructions(pilot, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert pilot_token = Repo.get_by(PilotToken, token: :crypto.hash(:sha256, token))
      assert pilot_token.pilot_id == pilot.id
      assert pilot_token.sent_to == pilot.email
      assert pilot_token.context == "confirm"
    end
  end

  describe "confirm_pilot/1" do
    setup do
      pilot = pilot_fixture()

      token =
        extract_pilot_token(fn url ->
          Accounts.deliver_pilot_confirmation_instructions(pilot, url)
        end)

      %{pilot: pilot, token: token}
    end

    test "confirms the email with a valid token", %{pilot: pilot, token: token} do
      assert {:ok, confirmed_pilot} = Accounts.confirm_pilot(token)
      assert confirmed_pilot.confirmed_at
      assert confirmed_pilot.confirmed_at != pilot.confirmed_at
      assert Repo.get!(Pilot, pilot.id).confirmed_at
      refute Repo.get_by(PilotToken, pilot_id: pilot.id)
    end

    test "does not confirm with invalid token", %{pilot: pilot} do
      assert Accounts.confirm_pilot("oops") == :error
      refute Repo.get!(Pilot, pilot.id).confirmed_at
      assert Repo.get_by(PilotToken, pilot_id: pilot.id)
    end

    test "does not confirm email if token expired", %{pilot: pilot, token: token} do
      {1, nil} = Repo.update_all(PilotToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_pilot(token) == :error
      refute Repo.get!(Pilot, pilot.id).confirmed_at
      assert Repo.get_by(PilotToken, pilot_id: pilot.id)
    end
  end

  describe "deliver_pilot_reset_password_instructions/2" do
    setup do
      %{pilot: pilot_fixture()}
    end

    test "sends token through notification", %{pilot: pilot} do
      token =
        extract_pilot_token(fn url ->
          Accounts.deliver_pilot_reset_password_instructions(pilot, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert pilot_token = Repo.get_by(PilotToken, token: :crypto.hash(:sha256, token))
      assert pilot_token.pilot_id == pilot.id
      assert pilot_token.sent_to == pilot.email
      assert pilot_token.context == "reset_password"
    end
  end

  describe "get_pilot_by_reset_password_token/1" do
    setup do
      pilot = pilot_fixture()

      token =
        extract_pilot_token(fn url ->
          Accounts.deliver_pilot_reset_password_instructions(pilot, url)
        end)

      %{pilot: pilot, token: token}
    end

    test "returns the pilot with valid token", %{pilot: %{id: id}, token: token} do
      assert %Pilot{id: ^id} = Accounts.get_pilot_by_reset_password_token(token)
      assert Repo.get_by(PilotToken, pilot_id: id)
    end

    test "does not return the pilot with invalid token", %{pilot: pilot} do
      refute Accounts.get_pilot_by_reset_password_token("oops")
      assert Repo.get_by(PilotToken, pilot_id: pilot.id)
    end

    test "does not return the pilot if token expired", %{pilot: pilot, token: token} do
      {1, nil} = Repo.update_all(PilotToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_pilot_by_reset_password_token(token)
      assert Repo.get_by(PilotToken, pilot_id: pilot.id)
    end
  end

  describe "reset_pilot_password/2" do
    setup do
      %{pilot: pilot_fixture()}
    end

    test "validates password", %{pilot: pilot} do
      {:error, changeset} =
        Accounts.reset_pilot_password(pilot, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{pilot: pilot} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_pilot_password(pilot, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{pilot: pilot} do
      {:ok, updated_pilot} = Accounts.reset_pilot_password(pilot, %{password: "new valid password"})
      assert is_nil(updated_pilot.password)
      assert Accounts.get_pilot_by_email_and_password(pilot.email, "new valid password")
    end

    test "deletes all tokens for the given pilot", %{pilot: pilot} do
      _ = Accounts.generate_pilot_session_token(pilot)
      {:ok, _} = Accounts.reset_pilot_password(pilot, %{password: "new valid password"})
      refute Repo.get_by(PilotToken, pilot_id: pilot.id)
    end
  end

  describe "inspect/2 for the Pilot module" do
    test "does not include password" do
      refute inspect(%Pilot{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
