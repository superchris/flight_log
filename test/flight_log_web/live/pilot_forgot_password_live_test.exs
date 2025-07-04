defmodule FlightLogWeb.PilotForgotPasswordLiveTest do
  use FlightLogWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FlightLog.AccountsFixtures

  alias FlightLog.Accounts
  alias FlightLog.Repo

  describe "Forgot password page" do
    test "renders email page", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/pilots/reset_password")

      assert html =~ "Forgot your password?"
      assert has_element?(lv, ~s|a[href="#{~p"/pilots/register"}"]|, "Register")
      assert has_element?(lv, ~s|a[href="#{~p"/pilots/log_in"}"]|, "Log in")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_pilot(pilot_fixture())
        |> live(~p"/pilots/reset_password")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end
  end

  describe "Reset link" do
    setup do
      %{pilot: pilot_fixture()}
    end

    test "sends a new reset password token", %{conn: conn, pilot: pilot} do
      {:ok, lv, _html} = live(conn, ~p"/pilots/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", pilot: %{"email" => pilot.email})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"

      assert Repo.get_by!(Accounts.PilotToken, pilot_id: pilot.id).context ==
               "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/pilots/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", pilot: %{"email" => "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.PilotToken) == []
    end
  end
end
