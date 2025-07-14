defmodule FlightLogWeb.PilotConfirmationLiveTest do
  use FlightLogWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FlightLog.AccountsFixtures

  alias FlightLog.Accounts
  alias FlightLog.Repo

  setup do
    %{pilot: pilot_fixture()}
  end

  describe "Confirm pilot" do
    test "renders confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/pilots/confirm/some-token")
      assert html =~ "Confirm Account"
    end

    test "confirms the given token once", %{conn: conn, pilot: pilot} do
      token =
        extract_pilot_token(fn url ->
          Accounts.deliver_pilot_confirmation_instructions(pilot, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/pilots/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Pilot confirmed successfully"

      assert Accounts.get_pilot!(pilot.id).confirmed_at
      refute get_session(conn, :pilot_token)
      assert Repo.all(Accounts.PilotToken) == []

      # when not logged in
      {:ok, lv, _html} = live(conn, ~p"/pilots/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/pilots/log_in")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Pilot confirmation link is invalid or it has expired"

      # when logged in
      conn =
        build_conn()
        |> log_in_pilot(pilot)

      {:ok, lv, _html} = live(conn, ~p"/pilots/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, pilot: pilot} do
      {:ok, lv, _html} = live(conn, ~p"/pilots/confirm/invalid-token")

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/pilots/log_in")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Pilot confirmation link is invalid or it has expired"

      refute Accounts.get_pilot!(pilot.id).confirmed_at
    end
  end
end
