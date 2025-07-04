defmodule FlightLogWeb.FlightLive.LogFlightTest do
  use FlightLogWeb.ConnCase

  import Phoenix.LiveViewTest
  import FlightLog.AirplanesFixtures

  @create_attrs %{
    "hobbs_reading" => "120.5",
    "flight_date" => "2024-01-15",
    "notes" => "Great weather, smooth flight"
  }

  @invalid_attrs %{
    "hobbs_reading" => "",
    "flight_date" => ""
  }

  describe "Authenticated pilot" do
    setup [:register_and_log_in_pilot, :create_airplane]

    test "can access flight by tail number page", %{conn: conn, airplane: airplane} do
      {:ok, _lv, html} = live(conn, ~p"/flights/#{airplane.tail_number}/new")

      assert html =~ "Log Flight - #{airplane.tail_number}"
      assert html =~ "Flying #{airplane.make} #{airplane.model}"
    end

    test "shows error for non-existent tail number", %{conn: conn} do
      {:error, {:redirect, %{to: "/flights", flash: flash}}} = live(conn, ~p"/flights/NONEXISTENT/new")

      assert flash["error"] == "Airplane with tail number 'NONEXISTENT' not found."
    end

    test "can create a flight with valid data", %{conn: conn, pilot: pilot, airplane: airplane} do
      {:ok, lv, _html} = live(conn, ~p"/flights/#{airplane.tail_number}/new")

      assert lv
             |> form("#flight-form", flight: @create_attrs)
             |> render_submit()

      assert_redirect(lv, ~p"/flights")

      # Verify the flight was created
      flight = FlightLog.Flights.list_flights() |> List.last()
      assert flight.pilot_id == pilot.id
      assert flight.airplane_id == airplane.id
      assert Decimal.equal?(flight.hobbs_reading, Decimal.new("120.5"))
      assert flight.flight_date == ~D[2024-01-15]
      assert flight.notes == "Great weather, smooth flight"
    end

    test "shows validation errors for invalid data", %{conn: conn, airplane: airplane} do
      {:ok, lv, _html} = live(conn, ~p"/flights/#{airplane.tail_number}/new")

      assert lv
             |> form("#flight-form", flight: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"
    end

    test "validates hobbs reading as required", %{conn: conn, airplane: airplane} do
      {:ok, lv, _html} = live(conn, ~p"/flights/#{airplane.tail_number}/new")

      invalid_attrs = Map.put(@create_attrs, "hobbs_reading", "")

      assert lv
             |> form("#flight-form", flight: invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"
    end

    test "validates flight date as required", %{conn: conn, airplane: airplane} do
      {:ok, lv, _html} = live(conn, ~p"/flights/#{airplane.tail_number}/new")

      invalid_attrs = Map.put(@create_attrs, "flight_date", "")

      assert lv
             |> form("#flight-form", flight: invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"
    end

    test "pre-fills pilot and airplane from URL and current user", %{conn: conn, pilot: pilot, airplane: airplane} do
      {:ok, lv, _html} = live(conn, ~p"/flights/#{airplane.tail_number}/new")

      # Submit the form and check that the correct pilot and airplane are used
      lv
      |> form("#flight-form", flight: @create_attrs)
      |> render_submit()

      flight = FlightLog.Flights.list_flights() |> List.last()
      assert flight.pilot_id == pilot.id
      assert flight.airplane_id == airplane.id
    end

    test "redirects to flights index after successful creation", %{conn: conn, airplane: airplane} do
      {:ok, lv, _html} = live(conn, ~p"/flights/#{airplane.tail_number}/new")

      lv
      |> form("#flight-form", flight: @create_attrs)
      |> render_submit()

      assert_redirect(lv, ~p"/flights")
    end

    test "shows flash message after successful creation", %{conn: conn, airplane: airplane} do
      {:ok, lv, _html} = live(conn, ~p"/flights/#{airplane.tail_number}/new")

      lv
      |> form("#flight-form", flight: @create_attrs)
      |> render_submit()

      flash = assert_redirect(lv, ~p"/flights")
      assert flash["info"] == "Flight logged successfully!"
    end

    test "can create a flight without notes", %{conn: conn, pilot: pilot, airplane: airplane} do
      attrs_without_notes = Map.delete(@create_attrs, "notes")
      {:ok, lv, _html} = live(conn, ~p"/flights/#{airplane.tail_number}/new")

      assert lv
             |> form("#flight-form", flight: attrs_without_notes)
             |> render_submit()

      assert_redirect(lv, ~p"/flights")

      # Verify the flight was created without notes
      flight = FlightLog.Flights.list_flights() |> List.last()
      assert flight.pilot_id == pilot.id
      assert flight.airplane_id == airplane.id
      assert is_nil(flight.notes)
    end
  end

  describe "Unauthenticated user" do
    test "redirects to login page", %{conn: conn} do
      airplane = airplane_fixture()
      {:error, redirect} = live(conn, ~p"/flights/#{airplane.tail_number}/new")

      assert {:redirect, %{to: "/pilots/log_in"}} = redirect
    end
  end

  defp create_airplane(_) do
    airplane = airplane_fixture()
    %{airplane: airplane}
  end
end
