defmodule FlightLogWeb.AirplaneLiveTest do
  use FlightLogWeb.ConnCase

  import Phoenix.LiveViewTest
  import FlightLog.AirplanesFixtures

  @create_attrs %{year: 42, make: "some make", tail_number: "some tail_number", initial_hobbs_reading: "120.5", model: "some model"}
  @update_attrs %{year: 43, make: "some updated make", tail_number: "some updated tail_number", initial_hobbs_reading: "456.7", model: "some updated model"}
  @invalid_attrs %{year: nil, make: nil, tail_number: nil, initial_hobbs_reading: nil, model: nil}

  defp create_airplane(_) do
    airplane = airplane_fixture()
    %{airplane: airplane}
  end

  describe "Index" do
    setup [:create_airplane]

    test "lists all airplanes", %{conn: conn, airplane: airplane} do
      {:ok, _index_live, html} = live(conn, ~p"/airplanes")

      assert html =~ "Listing Airplanes"
      assert html =~ airplane.make
    end

    test "saves new airplane", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/airplanes")

      assert index_live |> element("a", "New Airplane") |> render_click() =~
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

      assert index_live |> element("#airplanes-#{airplane.id} a", "Edit") |> render_click() =~
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
    setup [:create_airplane]

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
  end
end
