defmodule FlightLogWeb.PilotMagicLinkLiveTest do
  use FlightLogWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FlightLog.AccountsFixtures

  alias FlightLog.Accounts
  alias FlightLog.Repo

  describe "Magic link page" do
    test "renders email page", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/pilots/magic_link")

      assert html =~ "Log in with email"
      assert has_element?(lv, ~s|a[href="#{~p"/pilots/log_in"}"]|, "Log in with password")
      assert has_element?(lv, ~s|a[href="#{~p"/pilots/register"}"]|, "Register")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_pilot(pilot_fixture())
        |> live(~p"/pilots/magic_link")
        # Pilot with no airplanes redirects to /airplanes
        |> follow_redirect(conn, ~p"/airplanes")

      assert {:ok, _conn} = result
    end
  end

  describe "Send magic link" do
    setup do
      %{pilot: pilot_fixture()}
    end

    test "sends a magic link token", %{conn: conn, pilot: pilot} do
      {:ok, lv, _html} = live(conn, ~p"/pilots/magic_link")

      {:ok, conn} =
        lv
        |> form("#magic_link_form", pilot: %{"email" => pilot.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/pilots/log_in")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Accounts.PilotToken, pilot_id: pilot.id).context == "magic_link"
    end

    test "does not send magic link token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/pilots/magic_link")

      {:ok, conn} =
        lv
        |> form("#magic_link_form", pilot: %{"email" => "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/pilots/log_in")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Accounts.PilotToken) == []
    end
  end
end
