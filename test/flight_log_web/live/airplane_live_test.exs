defmodule FlightLogWeb.AirplaneLiveTest do
  use FlightLogWeb.ConnCase

  import Phoenix.LiveViewTest
  import FlightLog.AirplanesFixtures
  import FlightLog.AccountsFixtures

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

    test "associates airplane with logged-in pilot when creating", %{conn: conn, pilot: pilot} do
      {:ok, index_live, _html} = live(conn, ~p"/airplanes")

      assert index_live |> element("a", "Add Aircraft") |> render_click() =~
               "New Airplane"

      assert_patch(index_live, ~p"/airplanes/new")

      unique_tail_number = "N#{System.unique_integer([:positive])}"
      create_attrs_with_unique_tail = Map.put(@create_attrs, :tail_number, unique_tail_number)

      assert index_live
             |> form("#airplane-form", airplane: create_attrs_with_unique_tail)
             |> render_submit()

      assert_patch(index_live, ~p"/airplanes")

      html = render(index_live)
      assert html =~ "Airplane created successfully"
      assert html =~ "some make"

      # Verify the airplane was associated with the logged-in pilot
      {:ok, airplane} = FlightLog.Airplanes.get_airplane_by_tail_number(unique_tail_number)
      airplane_with_pilots = FlightLog.Repo.preload(airplane, :pilots)
      assert Enum.any?(airplane_with_pilots.pilots, &(&1.id == pilot.id))
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

    test "displays pilots section", %{conn: conn, airplane: airplane} do
      {:ok, _show_live, html} = live(conn, ~p"/airplanes/#{airplane}")

      assert html =~ "Pilots"
      # The airplane fixture associates a pilot, so we should see them listed
      assert html =~ "John Doe"
    end

    test "can add a pilot to airplane", %{conn: conn, airplane: airplane} do
      other_pilot = pilot_fixture(first_name: "Jane", last_name: "Smith")

      {:ok, show_live, html} = live(conn, ~p"/airplanes/#{airplane}")

      # The airplane already has a pilot from fixture, Jane should be in dropdown
      assert html =~ "Jane Smith"

      show_live
      |> form("form", %{pilot_id: other_pilot.id})
      |> render_change()

      html = render(show_live)
      assert html =~ "Jane Smith (#{other_pilot.email})"
    end

    test "can remove a pilot from airplane", %{conn: conn, airplane: airplane} do
      other_pilot = pilot_fixture(first_name: "Jane", last_name: "Smith")
      {:ok, airplane} = FlightLog.Airplanes.add_pilot_to_airplane(airplane, other_pilot)

      {:ok, show_live, html} = live(conn, ~p"/airplanes/#{airplane}")

      # Jane should be in the assigned pilots list
      assert html =~ "Jane Smith (#{other_pilot.email})"
      # And should have a remove button
      assert has_element?(show_live, "[data-test-id=remove-pilot-#{other_pilot.id}]")

      # Trigger the remove_pilot event directly
      show_live
      |> render_click("remove_pilot", %{"pilot_id" => other_pilot.id})

      # Jane should no longer be in the assigned pilots list
      refute has_element?(show_live, "[data-test-id=remove-pilot-#{other_pilot.id}]")
    end

    test "available pilots dropdown excludes already assigned pilots", %{conn: conn, airplane: airplane} do
      pilot1 = pilot_fixture(first_name: "Pilot", last_name: "One")
      pilot2 = pilot_fixture(first_name: "Pilot", last_name: "Two")
      {:ok, airplane} = FlightLog.Airplanes.add_pilot_to_airplane(airplane, pilot1)

      {:ok, _show_live, html} = live(conn, ~p"/airplanes/#{airplane}")

      # pilot1 should be in the assigned list, not dropdown
      assert html =~ "Pilot One (#{pilot1.email})"
      # pilot2 should be in the dropdown as an option
      assert html =~ "<option value=\"#{pilot2.id}\">"
      # pilot1 should not be in the dropdown
      refute html =~ "<option value=\"#{pilot1.id}\">"
    end
  end
end
