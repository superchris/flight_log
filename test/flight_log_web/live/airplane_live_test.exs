defmodule FlightLogWeb.AirplaneLiveTest do
  use FlightLogWeb.ConnCase

  import Phoenix.LiveViewTest
  import FlightLog.AirplanesFixtures

  @create_attrs %{year: 42, make: "some make", tail_number: "some tail_number", initial_hobbs_reading: "120.5", model: "some model"}
  @update_attrs %{year: 43, make: "some updated make", tail_number: "some updated tail_number", initial_hobbs_reading: "456.7", model: "some updated model"}
  @invalid_attrs %{year: nil, make: nil, tail_number: nil, initial_hobbs_reading: nil, model: nil}

  describe "Index" do
    setup [:create_airplane, :register_and_log_in_pilot]

    test "lists all airplanes", %{conn: conn, airplane: airplane} do
      {:ok, _index_live, html} = live(conn, ~p"/airplanes")

      assert html =~ "Listing Airplanes"
      assert html =~ airplane.make
    end

    test "saves new airplane", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/airplanes")

      assert index_live |> element("a", "Add Aircraft") |> render_click() =~
               "New Airplane"

      assert_patch(index_live, ~p"/airplanes/new")

      assert index_live
             |> form("#airplane-form", airplane: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#airplane-form", airplane: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/airplanes")

      html = render(index_live)
      assert html =~ "Airplane created successfully"
      assert html =~ "some make"
    end

    test "updates airplane in listing", %{conn: conn, airplane: airplane} do
      {:ok, index_live, _html} = live(conn, ~p"/airplanes")

      assert index_live |> element("#airplanes-#{airplane.id} a[href$='/edit']") |> render_click() =~
               "Edit Airplane"

      assert_patch(index_live, ~p"/airplanes/#{airplane}/edit")

      assert index_live
             |> form("#airplane-form", airplane: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#airplane-form", airplane: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/airplanes")

      html = render(index_live)
      assert html =~ "Airplane updated successfully"
      assert html =~ "some updated make"
    end

    test "deletes airplane in listing", %{conn: conn, airplane: airplane} do
      {:ok, index_live, _html} = live(conn, ~p"/airplanes")

      assert index_live |> element("#airplanes-#{airplane.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#airplanes-#{airplane.id}")
    end
  end

  describe "Show" do
    setup [:create_airplane, :register_and_log_in_pilot]

    test "displays airplane", %{conn: conn, airplane: airplane} do
      {:ok, _show_live, html} = live(conn, ~p"/airplanes/#{airplane}")

      assert html =~ "Show Airplane"
      assert html =~ airplane.make
    end

    test "updates airplane within modal", %{conn: conn, airplane: airplane} do
      {:ok, show_live, _html} = live(conn, ~p"/airplanes/#{airplane}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Airplane"

      assert_patch(show_live, ~p"/airplanes/#{airplane}/show/edit")

      assert show_live
             |> form("#airplane-form", airplane: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#airplane-form", airplane: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/airplanes/#{airplane}")

      html = render(show_live)
      assert html =~ "Airplane updated successfully"
      assert html =~ "some updated make"
    end

    test "displays costs section", %{conn: conn, airplane: airplane} do
      {:ok, _show_live, html} = live(conn, ~p"/airplanes/#{airplane}")

      assert html =~ "Costs"
      assert html =~ "Add Cost"
      assert html =~ "No costs have been added yet"
    end

    test "displays existing costs", %{conn: conn} do
      import FlightLog.CostsFixtures
      airplane = airplane_fixture()
      cost = cost_fixture(airplane: airplane)

      {:ok, _show_live, html} = live(conn, ~p"/airplanes/#{airplane}")

      assert html =~ "Costs"
      assert html =~ "Monthly"
      assert html =~ "$#{cost.amount}"
      assert html =~ cost.description
    end

    test "can delete cost", %{conn: conn} do
      import FlightLog.CostsFixtures
      airplane = airplane_fixture()
      cost = cost_fixture(airplane: airplane)

      {:ok, show_live, _html} = live(conn, ~p"/airplanes/#{airplane}")

      assert render(show_live) =~ cost.description

      # Use a more specific selector for the delete button
      assert show_live
             |> element("a[data-confirm]", "Delete")
             |> render_click()

      refute render(show_live) =~ cost.description
      assert render(show_live) =~ "No costs have been added yet"
    end
  end
end
