defmodule FlightLogWeb.FlightLiveTest do
  use FlightLogWeb.ConnCase

  import Phoenix.LiveViewTest
  import FlightLog.FlightsFixtures
  import FlightLog.AccountsFixtures
  import FlightLog.AirplanesFixtures

  defp create_flight(_) do
    flight = flight_fixture()
    %{flight: flight}
  end

  defp create_test_data(_) do
    pilot = pilot_fixture()
    airplane = airplane_fixture()

    %{
      pilot: pilot,
      airplane: airplane,
      create_attrs: %{hobbs_reading: "120.5", flight_date: "2025-07-03", pilot_id: pilot.id, airplane_id: airplane.id},
      update_attrs: %{hobbs_reading: "456.7", flight_date: "2025-07-04", pilot_id: pilot.id, airplane_id: airplane.id},
      invalid_attrs: %{hobbs_reading: nil, flight_date: nil, pilot_id: nil, airplane_id: nil}
    }
  end

  describe "Index" do
    setup [:create_flight, :create_test_data]

    test "lists all flights", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/flights")

      assert html =~ "Listing Flights"
    end

    test "saves new flight", %{conn: conn, create_attrs: create_attrs, invalid_attrs: invalid_attrs} do
      {:ok, index_live, _html} = live(conn, ~p"/flights")

      assert index_live |> element("a", "New Flight") |> render_click() =~
               "New Flight"

      assert_patch(index_live, ~p"/flights/new")

      assert index_live
             |> form("#flight-form", flight: invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#flight-form", flight: create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/flights")

      html = render(index_live)
      assert html =~ "Flight created successfully"
    end

    test "updates flight in listing", %{conn: conn, flight: flight, update_attrs: update_attrs, invalid_attrs: invalid_attrs} do
      {:ok, index_live, _html} = live(conn, ~p"/flights")

      assert index_live |> element("#flights-#{flight.id} a", "Edit") |> render_click() =~
               "Edit Flight"

      assert_patch(index_live, ~p"/flights/#{flight}/edit")

      assert index_live
             |> form("#flight-form", flight: invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#flight-form", flight: update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/flights")

      html = render(index_live)
      assert html =~ "Flight updated successfully"
    end

    test "deletes flight in listing", %{conn: conn, flight: flight} do
      {:ok, index_live, _html} = live(conn, ~p"/flights")

      assert index_live |> element("#flights-#{flight.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#flights-#{flight.id}")
    end
  end

  describe "Show" do
    setup [:create_flight, :create_test_data]

    test "displays flight", %{conn: conn, flight: flight} do
      {:ok, _show_live, html} = live(conn, ~p"/flights/#{flight}")

      assert html =~ "Show Flight"
    end

    test "updates flight within modal", %{conn: conn, flight: flight, update_attrs: update_attrs, invalid_attrs: invalid_attrs} do
      {:ok, show_live, _html} = live(conn, ~p"/flights/#{flight}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Flight"

      assert_patch(show_live, ~p"/flights/#{flight}/show/edit")

      assert show_live
             |> form("#flight-form", flight: invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#flight-form", flight: update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/flights/#{flight}")

      html = render(show_live)
      assert html =~ "Flight updated successfully"
    end
  end
end
