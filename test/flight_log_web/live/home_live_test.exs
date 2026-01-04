defmodule FlightLogWeb.HomeLiveTest do
  use FlightLogWeb.ConnCase

  import Phoenix.LiveViewTest
  import FlightLog.AirplanesFixtures

  describe "Home redirect" do
    setup [:register_and_log_in_pilot]

    test "redirects to monthly view when pilot has an airplane", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{pilot: pilot, tail_number: "N12345"})

      {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/")

      assert path == "/flights/monthly/#{airplane.tail_number}"
    end

    test "redirects to airplanes page when pilot has no airplanes", %{conn: conn} do
      {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/")

      assert path == "/airplanes"
    end
  end
end
