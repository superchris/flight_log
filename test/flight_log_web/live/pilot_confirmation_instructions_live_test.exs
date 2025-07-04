defmodule FlightLogWeb.PilotConfirmationInstructionsLiveTest do
  use FlightLogWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FlightLog.AccountsFixtures

  alias FlightLog.Accounts
  alias FlightLog.Repo

  setup do
    %{pilot: pilot_fixture()}
  end

  describe "Resend confirmation" do
    test "renders the resend confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/pilots/confirm")
      assert html =~ "Resend confirmation instructions"
    end

    test "sends a new confirmation token", %{conn: conn, pilot: pilot} do
      {:ok, lv, _html} = live(conn, ~p"/pilots/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", pilot: %{email: pilot.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Accounts.PilotToken, pilot_id: pilot.id).context == "confirm"
    end

    test "does not send confirmation token if pilot is confirmed", %{conn: conn, pilot: pilot} do
      Repo.update!(Accounts.Pilot.confirm_changeset(pilot))

      {:ok, lv, _html} = live(conn, ~p"/pilots/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", pilot: %{email: pilot.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      refute Repo.get_by(Accounts.PilotToken, pilot_id: pilot.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/pilots/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", pilot: %{email: "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Accounts.PilotToken) == []
    end
  end
end
