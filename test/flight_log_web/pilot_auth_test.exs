defmodule FlightLogWeb.PilotAuthTest do
  use FlightLogWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias FlightLog.Accounts
  alias FlightLogWeb.PilotAuth
  import FlightLog.AccountsFixtures
  import FlightLog.AirplanesFixtures

  @remember_me_cookie "_flight_log_web_pilot_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, FlightLogWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{pilot: pilot_fixture(), conn: conn}
  end

  describe "log_in_pilot/3" do
    test "stores the pilot token in the session and redirects to airplanes when pilot has none", %{conn: conn, pilot: pilot} do
      conn = PilotAuth.log_in_pilot(conn, pilot)
      assert token = get_session(conn, :pilot_token)
      assert get_session(conn, :live_socket_id) == "pilots_sessions:#{Base.url_encode64(token)}"
      # Pilot has no airplanes, so redirect to /airplanes
      assert redirected_to(conn) == ~p"/airplanes"
      assert Accounts.get_pilot_by_session_token(token)
    end

    test "redirects to monthly view when pilot has an airplane", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{pilot: pilot, tail_number: "N12345"})
      conn = PilotAuth.log_in_pilot(conn, pilot)
      assert redirected_to(conn) == ~p"/flights/monthly/#{airplane.tail_number}"
    end

    test "redirects to monthly view when pilot fetched fresh from database has an airplane", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{pilot: pilot, tail_number: "N12345"})
      # Simulate the real login flow by fetching pilot fresh from the database
      fresh_pilot = Accounts.get_pilot_by_email_and_password(pilot.email, valid_pilot_password())
      conn = PilotAuth.log_in_pilot(conn, fresh_pilot)
      assert redirected_to(conn) == ~p"/flights/monthly/#{airplane.tail_number}"
    end

    test "clears everything previously stored in the session", %{conn: conn, pilot: pilot} do
      conn = conn |> put_session(:to_be_removed, "value") |> PilotAuth.log_in_pilot(pilot)
      refute get_session(conn, :to_be_removed)
    end


    test "writes a cookie if remember_me is configured", %{conn: conn, pilot: pilot} do
      conn = conn |> fetch_cookies() |> PilotAuth.log_in_pilot(pilot, %{"remember_me" => "true"})
      assert get_session(conn, :pilot_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :pilot_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_pilot/1" do
    test "erases session and cookies", %{conn: conn, pilot: pilot} do
      pilot_token = Accounts.generate_pilot_session_token(pilot)

      conn =
        conn
        |> put_session(:pilot_token, pilot_token)
        |> put_req_cookie(@remember_me_cookie, pilot_token)
        |> fetch_cookies()
        |> PilotAuth.log_out_pilot()

      refute get_session(conn, :pilot_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Accounts.get_pilot_by_session_token(pilot_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "pilots_sessions:abcdef-token"
      FlightLogWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> PilotAuth.log_out_pilot()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if pilot is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> PilotAuth.log_out_pilot()
      refute get_session(conn, :pilot_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_pilot/2" do
    test "authenticates pilot from session", %{conn: conn, pilot: pilot} do
      pilot_token = Accounts.generate_pilot_session_token(pilot)
      conn = conn |> put_session(:pilot_token, pilot_token) |> PilotAuth.fetch_current_pilot([])
      assert conn.assigns.current_pilot.id == pilot.id
    end

    test "authenticates pilot from cookies", %{conn: conn, pilot: pilot} do
      logged_in_conn =
        conn |> fetch_cookies() |> PilotAuth.log_in_pilot(pilot, %{"remember_me" => "true"})

      pilot_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> PilotAuth.fetch_current_pilot([])

      assert conn.assigns.current_pilot.id == pilot.id
      assert get_session(conn, :pilot_token) == pilot_token

      assert get_session(conn, :live_socket_id) ==
               "pilots_sessions:#{Base.url_encode64(pilot_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, pilot: pilot} do
      _ = Accounts.generate_pilot_session_token(pilot)
      conn = PilotAuth.fetch_current_pilot(conn, [])
      refute get_session(conn, :pilot_token)
      refute conn.assigns.current_pilot
    end

    test "assigns first_airplane when pilot has airplanes", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{pilot: pilot, tail_number: "N12345"})
      pilot_token = Accounts.generate_pilot_session_token(pilot)
      conn = conn |> put_session(:pilot_token, pilot_token) |> PilotAuth.fetch_current_pilot([])
      assert conn.assigns.first_airplane.id == airplane.id
    end

    test "assigns nil to first_airplane when pilot has no airplanes", %{conn: conn, pilot: pilot} do
      pilot_token = Accounts.generate_pilot_session_token(pilot)
      conn = conn |> put_session(:pilot_token, pilot_token) |> PilotAuth.fetch_current_pilot([])
      assert conn.assigns.first_airplane == nil
    end

    test "assigns nil to first_airplane when not authenticated", %{conn: conn} do
      conn = PilotAuth.fetch_current_pilot(conn, [])
      assert conn.assigns.first_airplane == nil
    end
  end

  describe "on_mount :mount_current_pilot" do
    test "assigns current_pilot based on a valid pilot_token", %{conn: conn, pilot: pilot} do
      pilot_token = Accounts.generate_pilot_session_token(pilot)
      session = conn |> put_session(:pilot_token, pilot_token) |> get_session()

      {:cont, updated_socket} =
        PilotAuth.on_mount(:mount_current_pilot, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_pilot.id == pilot.id
    end

    test "assigns nil to current_pilot assign if there isn't a valid pilot_token", %{conn: conn} do
      pilot_token = "invalid_token"
      session = conn |> put_session(:pilot_token, pilot_token) |> get_session()

      {:cont, updated_socket} =
        PilotAuth.on_mount(:mount_current_pilot, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_pilot == nil
    end

    test "assigns nil to current_pilot assign if there isn't a pilot_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        PilotAuth.on_mount(:mount_current_pilot, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_pilot == nil
    end

    test "assigns first_airplane when pilot has airplanes", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{pilot: pilot, tail_number: "N12345"})
      pilot_token = Accounts.generate_pilot_session_token(pilot)
      session = conn |> put_session(:pilot_token, pilot_token) |> get_session()

      {:cont, updated_socket} =
        PilotAuth.on_mount(:mount_current_pilot, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.first_airplane.id == airplane.id
    end

    test "assigns nil to first_airplane when pilot has no airplanes", %{conn: conn, pilot: pilot} do
      pilot_token = Accounts.generate_pilot_session_token(pilot)
      session = conn |> put_session(:pilot_token, pilot_token) |> get_session()

      {:cont, updated_socket} =
        PilotAuth.on_mount(:mount_current_pilot, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.first_airplane == nil
    end
  end

  describe "on_mount :ensure_authenticated" do
    test "authenticates current_pilot based on a valid pilot_token", %{conn: conn, pilot: pilot} do
      pilot_token = Accounts.generate_pilot_session_token(pilot)
      session = conn |> put_session(:pilot_token, pilot_token) |> get_session()

      {:cont, updated_socket} =
        PilotAuth.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_pilot.id == pilot.id
    end

    test "redirects to login page if there isn't a valid pilot_token", %{conn: conn} do
      pilot_token = "invalid_token"
      session = conn |> put_session(:pilot_token, pilot_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: FlightLogWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = PilotAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_pilot == nil
    end

    test "redirects to login page if there isn't a pilot_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: FlightLogWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = PilotAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_pilot == nil
    end
  end

  describe "on_mount :redirect_if_pilot_is_authenticated" do
    test "redirects if there is an authenticated  pilot ", %{conn: conn, pilot: pilot} do
      pilot_token = Accounts.generate_pilot_session_token(pilot)
      session = conn |> put_session(:pilot_token, pilot_token) |> get_session()

      assert {:halt, _updated_socket} =
               PilotAuth.on_mount(
                 :redirect_if_pilot_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end

    test "doesn't redirect if there is no authenticated pilot", %{conn: conn} do
      session = conn |> get_session()

      assert {:cont, _updated_socket} =
               PilotAuth.on_mount(
                 :redirect_if_pilot_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end
  end

  describe "redirect_if_pilot_is_authenticated/2" do
    test "redirects to airplanes if pilot is authenticated but has no airplanes", %{conn: conn, pilot: pilot} do
      conn = conn |> assign(:current_pilot, pilot) |> PilotAuth.redirect_if_pilot_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == ~p"/airplanes"
    end

    test "redirects to monthly view if pilot is authenticated and has an airplane", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{pilot: pilot, tail_number: "N12345"})
      conn = conn |> assign(:current_pilot, pilot) |> PilotAuth.redirect_if_pilot_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == ~p"/flights/monthly/#{airplane.tail_number}"
    end

    test "does not redirect if pilot is not authenticated", %{conn: conn} do
      conn = PilotAuth.redirect_if_pilot_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_pilot/2" do
    test "redirects if pilot is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> PilotAuth.require_authenticated_pilot([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/pilots/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> PilotAuth.require_authenticated_pilot([])

      assert halted_conn.halted
      assert get_session(halted_conn, :pilot_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> PilotAuth.require_authenticated_pilot([])

      assert halted_conn.halted
      assert get_session(halted_conn, :pilot_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> PilotAuth.require_authenticated_pilot([])

      assert halted_conn.halted
      refute get_session(halted_conn, :pilot_return_to)
    end

    test "does not redirect if pilot is authenticated", %{conn: conn, pilot: pilot} do
      conn = conn |> assign(:current_pilot, pilot) |> PilotAuth.require_authenticated_pilot([])
      refute conn.halted
      refute conn.status
    end
  end
end
