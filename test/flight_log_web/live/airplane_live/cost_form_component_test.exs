defmodule FlightLogWeb.AirplaneLive.CostFormComponentTest do
  use FlightLogWeb.ConnCase

  import Phoenix.LiveViewTest
  import FlightLog.AirplanesFixtures
  import FlightLog.CostsFixtures

  @create_attrs %{
    cost_type: :monthly,
    amount: "1200.50",
    description: "Monthly insurance premium"
  }

  @update_attrs %{
    cost_type: :hourly,
    amount: "125.75",
    description: "Updated fuel cost"
  }

  @invalid_attrs %{
    cost_type: nil,
    amount: nil,
    description: nil
  }

  setup :register_and_log_in_pilot

  describe "New Cost" do
    test "renders new cost form", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, show_live, _html} = live(conn, ~p"/airplanes/#{airplane.id}")

      assert show_live |> element("a", "Add Cost") |> render_click() =~
               "New Cost"

      assert_patch(show_live, ~p"/airplanes/#{airplane.id}/costs/new")

      assert render(show_live) =~ "New Cost"
      assert render(show_live) =~ "Cost Type"
      assert render(show_live) =~ "Amount"
      assert render(show_live) =~ "Description"
    end

    test "saves new cost with valid data", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, show_live, _html} = live(conn, ~p"/airplanes/#{airplane.id}")

      assert show_live |> element("a", "Add Cost") |> render_click() =~
               "New Cost"

      assert_patch(show_live, ~p"/airplanes/#{airplane.id}/costs/new")

      assert show_live
             |> form("#cost-form", cost: @create_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/airplanes/#{airplane.id}")

      html = render(show_live)
      assert html =~ "Cost created successfully"
      assert html =~ "Monthly"
      assert html =~ "$1200.50"
      assert html =~ "Monthly insurance premium"
    end

    test "shows validation errors for invalid data", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, show_live, _html} = live(conn, ~p"/airplanes/#{airplane.id}")

      assert show_live |> element("a", "Add Cost") |> render_click() =~
               "New Cost"

      assert_patch(show_live, ~p"/airplanes/#{airplane.id}/costs/new")

      assert show_live
             |> form("#cost-form", cost: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#cost-form", cost: @invalid_attrs)
             |> render_submit()

      assert render(show_live) =~ "can&#39;t be blank"
    end

        test "validates cost type selection", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, show_live, _html} = live(conn, ~p"/airplanes/#{airplane.id}")

      assert show_live |> element("a", "Add Cost") |> render_click() =~
               "New Cost"

      # Submit without selecting a cost type to trigger required validation
      invalid_attrs = %{cost_type: "", amount: "100.00"}

      assert show_live
             |> form("#cost-form", cost: invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"
    end

    test "validates positive amount", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, show_live, _html} = live(conn, ~p"/airplanes/#{airplane.id}")

      assert show_live |> element("a", "Add Cost") |> render_click() =~
               "New Cost"

      invalid_attrs = %{cost_type: :monthly, amount: "-100.00"}

      assert show_live
             |> form("#cost-form", cost: invalid_attrs)
             |> render_change() =~ "must be greater than 0"
    end

    test "validates zero amount", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, show_live, _html} = live(conn, ~p"/airplanes/#{airplane.id}")

      assert show_live |> element("a", "Add Cost") |> render_click() =~
               "New Cost"

      invalid_attrs = %{cost_type: :monthly, amount: "0.00"}

      assert show_live
             |> form("#cost-form", cost: invalid_attrs)
             |> render_change() =~ "must be greater than 0"
    end

    test "allows optional description", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, show_live, _html} = live(conn, ~p"/airplanes/#{airplane.id}")

      assert show_live |> element("a", "Add Cost") |> render_click() =~
               "New Cost"

      attrs_without_description = %{cost_type: :hourly, amount: "50.00"}

      assert show_live
             |> form("#cost-form", cost: attrs_without_description)
             |> render_submit()

      assert_patch(show_live, ~p"/airplanes/#{airplane.id}")

      html = render(show_live)
      assert html =~ "Cost created successfully"
      assert html =~ "Hourly"
      assert html =~ "$50.00"
      assert html =~ "—"  # Empty description placeholder
    end
  end

  describe "Edit Cost" do
    test "renders edit cost form", %{conn: conn} do
      airplane = airplane_fixture()
      cost = cost_fixture(airplane: airplane)

      {:ok, show_live, _html} = live(conn, ~p"/airplanes/#{airplane.id}")

      assert show_live |> element("[data-test-id='edit-cost-#{cost.id}']", "Edit") |> render_click() =~
               "Edit Cost"

      assert_patch(show_live, ~p"/airplanes/#{airplane.id}/costs/#{cost.id}/edit")

      assert render(show_live) =~ "Edit Cost"
      assert render(show_live) =~ cost.description
    end

    test "updates cost with valid data", %{conn: conn} do
      airplane = airplane_fixture()
      cost = cost_fixture(airplane: airplane)

      {:ok, show_live, _html} = live(conn, ~p"/airplanes/#{airplane.id}")

      assert show_live |> element("[data-test-id='edit-cost-#{cost.id}']", "Edit") |> render_click() =~
               "Edit Cost"

      assert_patch(show_live, ~p"/airplanes/#{airplane.id}/costs/#{cost.id}/edit")

      assert show_live
             |> form("#cost-form", cost: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/airplanes/#{airplane.id}")

      html = render(show_live)
      assert html =~ "Cost updated successfully"
      assert html =~ "Hourly"
      assert html =~ "$125.75"
      assert html =~ "Updated fuel cost"
    end

    test "shows validation errors for invalid data", %{conn: conn} do
      airplane = airplane_fixture()
      cost = cost_fixture(airplane: airplane)

      {:ok, show_live, _html} = live(conn, ~p"/airplanes/#{airplane.id}")

      assert show_live |> element("[data-test-id='edit-cost-#{cost.id}']", "Edit") |> render_click() =~
               "Edit Cost"

      assert show_live
             |> form("#cost-form", cost: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#cost-form", cost: @invalid_attrs)
             |> render_submit()

      assert render(show_live) =~ "can&#39;t be blank"
    end
  end

  describe "Form Interaction" do
    test "cost type select has all valid options", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, show_live, _html} = live(conn, ~p"/airplanes/#{airplane.id}")

      assert show_live |> element("a", "Add Cost") |> render_click() =~
               "New Cost"

      html = render(show_live)
      assert html =~ "Monthly"
      assert html =~ "Hourly"
      assert html =~ "One Time"
    end

    test "form validation triggers on change", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, show_live, _html} = live(conn, ~p"/airplanes/#{airplane.id}")

      assert show_live |> element("a", "Add Cost") |> render_click() =~
               "New Cost"

      # Start with valid data
      assert show_live
             |> form("#cost-form", cost: @create_attrs)
             |> render_change()

      # Change to invalid data
      assert show_live
             |> form("#cost-form", cost: %{cost_type: :monthly, amount: "-100"})
             |> render_change() =~ "must be greater than 0"
    end

            test "displays modal with form elements when adding cost", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, show_live, _html} = live(conn, ~p"/airplanes/#{airplane.id}")

      assert show_live |> element("a", "Add Cost") |> render_click() =~
               "New Cost"

      # Verify the modal is displayed with expected form elements
      html = render(show_live)
      assert html =~ "Cost Type"
      assert html =~ "Amount ($)"
      assert html =~ "Description (optional)"
      assert html =~ "Save Cost"
    end
  end
end
