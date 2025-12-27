defmodule FlightLogWeb.PilotLoginLiveTest do
  use FlightLogWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FlightLog.AccountsFixtures

  describe "Log in page" do
    test "renders log in page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/pilots/log_in")

      assert html =~ "Log in"
      assert html =~ "Register"
      assert html =~ "Forgot your password?"
      assert html =~ "Log in with email link"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_pilot(pilot_fixture())
        |> live(~p"/pilots/log_in")
        # Pilot with no airplanes redirects to /airplanes
        |> follow_redirect(conn, "/airplanes")

      assert {:ok, _conn} = result
    end
  end

  describe "pilot login" do
    test "redirects if pilot login with valid credentials", %{conn: conn} do
      password = "123456789abcd"
      pilot = pilot_fixture(%{password: password})

      {:ok, lv, _html} = live(conn, ~p"/pilots/log_in")

      form =
        form(lv, "#login_form", pilot: %{email: pilot.email, password: password, remember_me: true})

      conn = submit_form(form, conn)

      # Pilot with no airplanes redirects to /airplanes
      assert redirected_to(conn) == ~p"/airplanes"
    end

    test "redirects to login page with a flash error if there are no valid credentials", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/pilots/log_in")

      form =
        form(lv, "#login_form",
          pilot: %{email: "test@email.com", password: "123456", remember_me: true}
        )

      conn = submit_form(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"

      assert redirected_to(conn) == "/pilots/log_in"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/pilots/log_in")

      {:ok, _login_live, login_html} =
        lv
        |> element(~s|main a:fl-contains("Sign up")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/pilots/register")

      assert login_html =~ "Register"
    end

    test "redirects to forgot password page when the Forgot Password button is clicked", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/pilots/log_in")

      {:ok, conn} =
        lv
        |> element(~s|main a:fl-contains("Forgot your password?")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/pilots/reset_password")

      assert conn.resp_body =~ "Forgot your password?"
    end

    test "redirects to magic link page when the email link button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/pilots/log_in")

      {:ok, _lv, html} =
        lv
        |> element(~s|main a:fl-contains("Log in with email link")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/pilots/magic_link")

      assert html =~ "Log in with email"
    end
  end
end
