defmodule FlightLogWeb.PilotSettingsLiveTest do
  use FlightLogWeb.ConnCase, async: true

  alias FlightLog.Accounts
  import Phoenix.LiveViewTest
  import FlightLog.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_pilot(pilot_fixture())
        |> live(~p"/pilots/settings")

      assert html =~ "Change Email"
      assert html =~ "Change Password"
    end

    test "redirects if pilot is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/pilots/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/pilots/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      password = valid_pilot_password()
      pilot = pilot_fixture(%{password: password})
      %{conn: log_in_pilot(conn, pilot), pilot: pilot, password: password}
    end

    test "updates the pilot email", %{conn: conn, password: password, pilot: pilot} do
      new_email = unique_pilot_email()

      {:ok, lv, _html} = live(conn, ~p"/pilots/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => password,
          "pilot" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_pilot_by_email(pilot.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/pilots/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "current_password" => "invalid",
          "pilot" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, pilot: pilot} do
      {:ok, lv, _html} = live(conn, ~p"/pilots/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => "invalid",
          "pilot" => %{"email" => pilot.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
      assert result =~ "is not valid"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_pilot_password()
      pilot = pilot_fixture(%{password: password})
      %{conn: log_in_pilot(conn, pilot), pilot: pilot, password: password}
    end

    test "updates the pilot password", %{conn: conn, pilot: pilot, password: password} do
      new_password = valid_pilot_password()

      {:ok, lv, _html} = live(conn, ~p"/pilots/settings")

      form =
        form(lv, "#password_form", %{
          "current_password" => password,
          "pilot" => %{
            "email" => pilot.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      # Pilot with no airplanes redirects to /airplanes (ignores return_to)
      assert redirected_to(new_password_conn) == ~p"/airplanes"

      assert get_session(new_password_conn, :pilot_token) != get_session(conn, :pilot_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_pilot_by_email_and_password(pilot.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/pilots/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "current_password" => "invalid",
          "pilot" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/pilots/settings")

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "pilot" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
      assert result =~ "is not valid"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      pilot = pilot_fixture()
      email = unique_pilot_email()

      token =
        extract_pilot_token(fn url ->
          Accounts.deliver_pilot_update_email_instructions(%{pilot | email: email}, pilot.email, url)
        end)

      %{conn: log_in_pilot(conn, pilot), token: token, email: email, pilot: pilot}
    end

    test "updates the pilot email once", %{conn: conn, pilot: pilot, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/pilots/settings/confirm_email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/pilots/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_pilot_by_email(pilot.email)
      assert Accounts.get_pilot_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/pilots/settings/confirm_email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/pilots/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, pilot: pilot} do
      {:error, redirect} = live(conn, ~p"/pilots/settings/confirm_email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/pilots/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_pilot_by_email(pilot.email)
    end

    test "redirects if pilot is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/pilots/settings/confirm_email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/pilots/log_in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
