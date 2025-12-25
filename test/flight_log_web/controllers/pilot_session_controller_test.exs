defmodule FlightLogWeb.PilotSessionControllerTest do
  use FlightLogWeb.ConnCase, async: true

  import FlightLog.AccountsFixtures

  setup do
    %{pilot: pilot_fixture()}
  end

  describe "POST /pilots/log_in" do
    test "logs the pilot in", %{conn: conn, pilot: pilot} do
      conn =
        post(conn, ~p"/pilots/log_in", %{
          "pilot" => %{"email" => pilot.email, "password" => valid_pilot_password()}
        })

      assert get_session(conn, :pilot_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ "Welcome, John"  # The layout shows first_name, not email
      assert response =~ ~p"/pilots/settings"
      assert response =~ ~p"/pilots/log_out"
    end

    test "logs the pilot in with remember me", %{conn: conn, pilot: pilot} do
      conn =
        post(conn, ~p"/pilots/log_in", %{
          "pilot" => %{
            "email" => pilot.email,
            "password" => valid_pilot_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_flight_log_web_pilot_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the pilot in with return to", %{conn: conn, pilot: pilot} do
      conn =
        conn
        |> init_test_session(pilot_return_to: "/foo/bar")
        |> post(~p"/pilots/log_in", %{
          "pilot" => %{
            "email" => pilot.email,
            "password" => valid_pilot_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "login following registration", %{conn: conn, pilot: pilot} do
      conn =
        conn
        |> post(~p"/pilots/log_in", %{
          "_action" => "registered",
          "pilot" => %{
            "email" => pilot.email,
            "password" => valid_pilot_password()
          }
        })

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Account created successfully"
    end

    test "login following password update", %{conn: conn, pilot: pilot} do
      conn =
        conn
        |> post(~p"/pilots/log_in", %{
          "_action" => "password_updated",
          "pilot" => %{
            "email" => pilot.email,
            "password" => valid_pilot_password()
          }
        })

      assert redirected_to(conn) == ~p"/pilots/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password updated successfully"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/pilots/log_in", %{
          "pilot" => %{"email" => "invalid@email.com", "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/pilots/log_in"
    end
  end

  describe "DELETE /pilots/log_out" do
    test "logs the pilot out", %{conn: conn, pilot: pilot} do
      conn = conn |> log_in_pilot(pilot) |> delete(~p"/pilots/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :pilot_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the pilot is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/pilots/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :pilot_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end

  describe "GET /pilots/log_in/:token (magic link)" do
    test "logs the pilot in with valid magic link token", %{conn: conn, pilot: pilot} do
      token =
        extract_pilot_token(fn url ->
          FlightLog.Accounts.deliver_pilot_magic_link_instructions(pilot, url)
        end)

      conn = get(conn, ~p"/pilots/log_in/#{token}")
      assert get_session(conn, :pilot_token)
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "redirects to login page with invalid token", %{conn: conn} do
      conn = get(conn, ~p"/pilots/log_in/invalid-token")
      refute get_session(conn, :pilot_token)
      assert redirected_to(conn) == ~p"/pilots/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Magic link is invalid or has expired"
    end

    test "redirects to login page with expired token", %{conn: conn, pilot: pilot} do
      token =
        extract_pilot_token(fn url ->
          FlightLog.Accounts.deliver_pilot_magic_link_instructions(pilot, url)
        end)

      # Expire the token
      FlightLog.Repo.update_all(FlightLog.Accounts.PilotToken,
        set: [inserted_at: ~N[2020-01-01 00:00:00]]
      )

      conn = get(conn, ~p"/pilots/log_in/#{token}")
      refute get_session(conn, :pilot_token)
      assert redirected_to(conn) == ~p"/pilots/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Magic link is invalid or has expired"
    end
  end
end
