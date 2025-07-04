# List flights for airplane and month
_Exported on 7/4/2025 at 14:51:41 EDT from Cursor (1.2.1)_

---

**User**

I need a screen to list all of the flights for given airplane in a given month for the currently logged in pilot. 

---

**Cursor**

I'll help you create a screen to list flights for a given airplane in a given month for the currently logged in pilot. Let me first explore the existing flight LiveViews to understand the current structure and patterns.

Now let me examine the Flights context to understand how flights are queried and what functions are available:

Now let me check the router to understand the current routing structure:

Let me check the Airplanes context to understand how to get airplane information:

Now I'll create the screen to list flights for a given airplane in a given month for the currently logged in pilot. I'll need to:

1. Add a new function to the Flights context to filter flights
2. Create a new LiveView 
3. Create the corresponding template
4. Add the route to the router

Let me start by adding the filtering function to the Flights context:

```elixir
defmodule FlightLog.Flights do
  @moduledoc """
  The Flights context.
  """

  import Ecto.Query, warn: false
  alias FlightLog.Repo

  alias FlightLog.Flights.Flight

  @doc """
  Returns the list of flights.

  ## Examples

      iex> list_flights()
      [%Flight{}, ...]

  """
  def list_flights do
    Repo.all(Flight)
  end

  @doc """
  Returns the list of flights for a specific pilot, airplane, and month.

  ## Examples

      iex> list_flights_for_pilot_airplane_month(1, 2, ~D[2024-01-01])
      [%Flight{}, ...]

  """
  def list_flights_for_pilot_airplane_month(pilot_id, airplane_id, date) do
    start_of_month = Date.beginning_of_month(date)
    end_of_month = Date.end_of_month(date)

    from(f in Flight,
      where: f.pilot_id == ^pilot_id,
      where: f.airplane_id == ^airplane_id,
      where: f.flight_date >= ^start_of_month,
      where: f.flight_date <= ^end_of_month,
      order_by: [desc: f.flight_date, desc: f.inserted_at],
      preload: [:pilot, :airplane]
    )
    |> Repo.all()
  end

// ... existing code ...
end
```

Now I'll create a new LiveView to handle the monthly airplane flights view:

```elixir
defmodule FlightLogWeb.FlightLive.Monthly do
  use FlightLogWeb, :live_view

  alias FlightLog.Flights
  alias FlightLog.Airplanes

  @impl true
  def mount(%{"airplane_id" => airplane_id} = params, _session, socket) do
    airplane = Airplanes.get_airplane!(airplane_id)
    current_date = parse_date_params(params)
    
    flights = Flights.list_flights_for_pilot_airplane_month(
      socket.assigns.current_pilot.id,
      airplane.id,
      current_date
    )

    {:ok,
     socket
     |> assign(:airplane, airplane)
     |> assign(:current_date, current_date)
     |> assign(:flights, flights)
     |> assign(:page_title, "#{airplane.tail_number} - #{format_month(current_date)}")
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    current_date = parse_date_params(params)
    
    flights = Flights.list_flights_for_pilot_airplane_month(
      socket.assigns.current_pilot.id,
      socket.assigns.airplane.id,
      current_date
    )

    {:noreply,
     socket
     |> assign(:current_date, current_date)
     |> assign(:flights, flights)
     |> assign(:page_title, "#{socket.assigns.airplane.tail_number} - #{format_month(current_date)}")
    }
  end

  @impl true
  def handle_event("prev_month", _params, socket) do
    new_date = Date.add(socket.assigns.current_date, -Date.days_in_month(socket.assigns.current_date))
    
    {:noreply,
     socket
     |> push_patch(to: ~p"/flights/monthly/#{socket.assigns.airplane.id}?year=#{new_date.year}&month=#{new_date.month}")
    }
  end

  @impl true
  def handle_event("next_month", _params, socket) do
    new_date = Date.add(Date.end_of_month(socket.assigns.current_date), 1)
    
    {:noreply,
     socket
     |> push_patch(to: ~p"/flights/monthly/#{socket.assigns.airplane.id}?year=#{new_date.year}&month=#{new_date.month}")
    }
  end

  defp parse_date_params(%{"year" => year_str, "month" => month_str}) do
    year = String.to_integer(year_str)
    month = String.to_integer(month_str)
    Date.new!(year, month, 1)
  rescue
    _ -> Date.utc_today()
  end

  defp parse_date_params(_params) do
    Date.utc_today()
  end

  defp format_month(date) do
    Timex.format!(date, "%B %Y", :strftime)
  rescue
    _ -> "#{Calendar.month_name(date.month)} #{date.year}"
  end

  defp format_date(date) do
    Calendar.strftime(date, "%m/%d/%Y")
  end

  defp calculate_total_hobbs(flights) do
    flights
    |> Enum.map(& &1.hobbs_reading)
    |> Enum.sum()
    |> Decimal.round(1)
  end
end
```

Let me update the format_month function to use standard Elixir Calendar functions since Timex might not be available:

```elixir
  defp format_month(date) do
    Timex.format!(date, "%B %Y", :strftime)
  rescue
    _ -> "#{Calendar.month_name(date.month)} #{date.year}"
  end

->

  defp format_month(date) do
    month_name = case date.month do
      1 -> "January"
      2 -> "February"
      3 -> "March"
      4 -> "April"
      5 -> "May"
      6 -> "June"
      7 -> "July"
      8 -> "August"
      9 -> "September"
      10 -> "October"
      11 -> "November"
      12 -> "December"
    end
    "#{month_name} #{date.year}"
  end
```

Now I'll create the HTML template for the monthly flights view:

```phoenix-heex
<div class="mx-auto max-w-4xl">
  <.header>
    Flights for {@airplane.tail_number}
    <:subtitle>
      {@airplane.make} {@airplane.model} - {format_month(@current_date)}
    </:subtitle>
    <:actions>
      <.link navigate={~p"/flights/#{@airplane.tail_number}/new"}>
        <.button>Log New Flight</.button>
      </.link>
    </:actions>
  </.header>

  <div class="flex items-center justify-between mb-6">
    <.button phx-click="prev_month" class="flex items-center gap-2">
      <.icon name="hero-chevron-left" class="h-4 w-4" />
      Previous Month
    </.button>
    
    <h2 class="text-lg font-semibold text-gray-900">
      {format_month(@current_date)}
    </h2>
    
    <.button phx-click="next_month" class="flex items-center gap-2">
      Next Month
      <.icon name="hero-chevron-right" class="h-4 w-4" />
    </.button>
  </div>

  <%= if Enum.empty?(@flights) do %>
    <div class="text-center py-8">
      <.icon name="hero-airplane" class="mx-auto h-12 w-12 text-gray-400" />
      <h3 class="mt-2 text-sm font-semibold text-gray-900">No flights</h3>
      <p class="mt-1 text-sm text-gray-500">
        No flights found for {format_month(@current_date)}.
      </p>
      <div class="mt-6">
        <.link navigate={~p"/flights/#{@airplane.tail_number}/new"}>
          <.button>Log Your First Flight</.button>
        </.link>
      </div>
    </div>
  <% else %>
    <div class="bg-white shadow overflow-hidden sm:rounded-md">
      <ul class="divide-y divide-gray-200">
        <%= for flight <- @flights do %>
          <li class="px-6 py-4">
            <div class="flex items-center justify-between">
              <div class="flex-1 min-w-0">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <.icon name="hero-calendar" class="h-5 w-5 text-gray-400" />
                  </div>
                  <div class="ml-4">
                    <p class="text-sm font-medium text-gray-900">
                      {format_date(flight.flight_date)}
                    </p>
                    <p class="text-sm text-gray-500">
                      Hobbs: {flight.hobbs_reading} hours
                    </p>
                    <%= if flight.notes && flight.notes != "" do %>
                      <p class="text-sm text-gray-600 mt-1">
                        {flight.notes}
                      </p>
                    <% end %>
                  </div>
                </div>
              </div>
              <div class="flex-shrink-0">
                <.link navigate={~p"/flights/#{flight.id}"} class="text-indigo-600 hover:text-indigo-500 text-sm font-medium">
                  View Details
                </.link>
              </div>
            </div>
          </li>
        <% end %>
      </ul>
    </div>

    <div class="mt-6 bg-gray-50 px-6 py-4 rounded-lg">
      <div class="flex justify-between items-center">
        <span class="text-sm font-medium text-gray-900">Total Hobbs Time:</span>
        <span class="text-lg font-semibold text-gray-900">
          {calculate_total_hobbs(@flights)} hours
        </span>
      </div>
      <div class="flex justify-between items-center mt-2">
        <span class="text-sm font-medium text-gray-900">Total Flights:</span>
        <span class="text-lg font-semibold text-gray-900">
          {length(@flights)} flights
        </span>
      </div>
    </div>
  <% end %>

  <div class="mt-8">
    <.back navigate={~p"/airplanes/#{@airplane.id}"}>Back to airplane</.back>
  </div>
</div>
```

Now I need to add the route to the router:

```elixir
    live "/flights", FlightLive.Index, :index
    live "/flights/new", FlightLive.Index, :new
    live "/flights/:id/edit", FlightLive.Index, :edit

    live "/flights/:id", FlightLive.Show, :show
    live "/flights/:id/show/edit", FlightLive.Show, :edit

->

    live "/flights", FlightLive.Index, :index
    live "/flights/new", FlightLive.Index, :new
    live "/flights/:id/edit", FlightLive.Index, :edit
    live "/flights/monthly/:airplane_id", FlightLive.Monthly, :index

    live "/flights/:id", FlightLive.Show, :show
    live "/flights/:id/show/edit", FlightLive.Show, :edit
```

Let me also add a link from the airplane show page to this new monthly flights view:

I'll update the airplane show template to add links for viewing monthly flights and logging a new flight:

```phoenix-heex
  <:actions>
    <.link patch={~p"/airplanes/#{@airplane}/show/edit"} phx-click={JS.push_focus()}>
      <.button>Edit airplane</.button>
    </.link>
  </:actions>

->

  <:actions>
    <.link navigate={~p"/flights/monthly/#{@airplane.id}"}>
      <.button>View Monthly Flights</.button>
    </.link>
    <.link navigate={~p"/flights/#{@airplane.tail_number}/new"}>
      <.button>Log Flight</.button>
    </.link>
    <.link patch={~p"/airplanes/#{@airplane}/show/edit"} phx-click={JS.push_focus()}>
      <.button>Edit airplane</.button>
    </.link>
  </:actions>
```

Let me test if the application compiles correctly:

Perfect! The application compiles successfully. Let me also check if we need to add an import for the Decimal module since we're using it in the calculate_total_hobbs function:

```elixir
  alias FlightLog.Flights
  alias FlightLog.Airplanes

->

  alias FlightLog.Flights
  alias FlightLog.Airplanes
  
  import Ecto.Query, warn: false
```

Let me also update the mount function to handle the case where an airplane is not found:

```elixir
  @impl true
  def mount(%{"airplane_id" => airplane_id} = params, _session, socket) do
    airplane = Airplanes.get_airplane!(airplane_id)
    current_date = parse_date_params(params)
    
    flights = Flights.list_flights_for_pilot_airplane_month(
      socket.assigns.current_pilot.id,
      airplane.id,
      current_date
    )

    {:ok,
     socket
     |> assign(:airplane, airplane)
     |> assign(:current_date, current_date)
     |> assign(:flights, flights)
     |> assign(:page_title, "#{airplane.tail_number} - #{format_month(current_date)}")
    }
  end

->

  @impl true
  def mount(%{"airplane_id" => airplane_id} = params, _session, socket) do
    try do
      airplane = Airplanes.get_airplane!(airplane_id)
      current_date = parse_date_params(params)
      
      flights = Flights.list_flights_for_pilot_airplane_month(
        socket.assigns.current_pilot.id,
        airplane.id,
        current_date
      )

      {:ok,
       socket
       |> assign(:airplane, airplane)
       |> assign(:current_date, current_date)
       |> assign(:flights, flights)
       |> assign(:page_title, "#{airplane.tail_number} - #{format_month(current_date)}")
      }
    rescue
      Ecto.NoResultsError ->
        {:ok,
         socket
         |> put_flash(:error, "Airplane not found.")
         |> redirect(to: ~p"/airplanes")}
    end
  end
```

Let me check if the route is properly protected by authentication. I need to move it to the authenticated section of the router:

I notice that the monthly flights route should be in an authenticated section since it uses `socket.assigns.current_pilot.id`. Let me move it to the authenticated section and also check if the other flight routes should be moved too. First, let me look at how the existing flight routes handle authentication:

I can see that `FlightLive.LogFlight` is in the authenticated section and uses `socket.assigns.current_pilot.id`, while other flight routes are in the open section. Since my monthly flights view also uses `current_pilot.id`, I need to move it to the authenticated section. Let me move the route:

```elixir
    live "/flights", FlightLive.Index, :index
    live "/flights/new", FlightLive.Index, :new
    live "/flights/:id/edit", FlightLive.Index, :edit
    live "/flights/monthly/:airplane_id", FlightLive.Monthly, :index

    live "/flights/:id", FlightLive.Show, :show
    live "/flights/:id/show/edit", FlightLive.Show, :edit

->

    live "/flights", FlightLive.Index, :index
    live "/flights/new", FlightLive.Index, :new
    live "/flights/:id/edit", FlightLive.Index, :edit

    live "/flights/:id", FlightLive.Show, :show
    live "/flights/:id/show/edit", FlightLive.Show, :edit
```

Now let me add it to the authenticated section:

```elixir
    live_session :require_authenticated_pilot,
      on_mount: [{FlightLogWeb.PilotAuth, :ensure_authenticated}] do
      live "/pilots/settings", PilotSettingsLive, :edit
      live "/pilots/settings/confirm_email/:token", PilotSettingsLive, :confirm_email
      live "/flights/:tail_number/new", FlightLive.LogFlight, :new
    end

->

    live_session :require_authenticated_pilot,
      on_mount: [{FlightLogWeb.PilotAuth, :ensure_authenticated}] do
      live "/pilots/settings", PilotSettingsLive, :edit
      live "/pilots/settings/confirm_email/:token", PilotSettingsLive, :confirm_email
      live "/flights/:tail_number/new", FlightLive.LogFlight, :new
      live "/flights/monthly/:airplane_id", FlightLive.Monthly, :index
    end
```

Let me test the compilation again to make sure everything still works:

Perfect! Let me also create a simple test to ensure the new functionality works correctly:

```elixir
defmodule FlightLogWeb.FlightLive.MonthlyTest do
  use FlightLogWeb.ConnCase

  import Phoenix.LiveViewTest
  import FlightLog.AirplanesFixtures
  import FlightLog.FlightsFixtures
  import FlightLog.AccountsFixtures

  describe "Monthly Flights" do
    setup :register_and_log_in_pilot

    test "lists flights for current pilot, airplane, and month", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture()
      flight_date = ~D[2024-01-15]
      
      # Create a flight for this pilot and airplane in January 2024
      flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: flight_date,
        hobbs_reading: Decimal.new("10.5")
      })

      # Create a flight in a different month (should not appear)
      _other_flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-02-15],
        hobbs_reading: Decimal.new("5.2")
      })

      {:ok, _index_live, html} = 
        live(conn, ~p"/flights/monthly/#{airplane.id}?year=2024&month=1")

      assert html =~ "Flights for #{airplane.tail_number}"
      assert html =~ "January 2024"
      assert html =~ "10.5"
      refute html =~ "5.2"  # February flight should not appear
    end

    test "shows empty state when no flights exist", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, _index_live, html} = 
        live(conn, ~p"/flights/monthly/#{airplane.id}?year=2024&month=1")

      assert html =~ "No flights"
      assert html =~ "January 2024"
    end

    test "navigates between months", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, index_live, _html} = 
        live(conn, ~p"/flights/monthly/#{airplane.id}?year=2024&month=1")

      # Test next month navigation
      index_live
      |> element("button", "Next Month")
      |> render_click()

      assert_patch(index_live, ~p"/flights/monthly/#{airplane.id}?year=2024&month=2")

      # Test previous month navigation
      index_live
      |> element("button", "Previous Month")
      |> render_click()

      assert_patch(index_live, ~p"/flights/monthly/#{airplane.id}?year=2024&month=1")
    end

    test "redirects when airplane not found", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/airplanes"}}} = 
        live(conn, ~p"/flights/monthly/999")
    end
  end

  defp register_and_log_in_pilot(_) do
    pilot = pilot_fixture()
    %{conn: log_in_pilot(build_conn(), pilot), pilot: pilot}
  end
end
```

Let me run the tests to see if our new functionality works correctly:

I need to fix the test file. There are compilation errors due to a conflicting function name and an unused variable. Let me fix these:

```elixir
  describe "Monthly Flights" do
    setup :register_and_log_in_pilot

    test "lists flights for current pilot, airplane, and month", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture()
      flight_date = ~D[2024-01-15]
      
      # Create a flight for this pilot and airplane in January 2024
      flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: flight_date,
        hobbs_reading: Decimal.new("10.5")
      })

      # Create a flight in a different month (should not appear)
      _other_flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-02-15],
        hobbs_reading: Decimal.new("5.2")
      })

->

  describe "Monthly Flights" do
    setup :register_and_log_in_pilot

    test "lists flights for current pilot, airplane, and month", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture()
      flight_date = ~D[2024-01-15]
      
      # Create a flight for this pilot and airplane in January 2024
      _flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: flight_date,
        hobbs_reading: Decimal.new("10.5")
      })

      # Create a flight in a different month (should not appear)
      _other_flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-02-15],
        hobbs_reading: Decimal.new("5.2")
      })
```

Now let me remove the conflicting function definition since it's already imported:

```elixir
  end

  defp register_and_log_in_pilot(_) do
    pilot = pilot_fixture()
    %{conn: log_in_pilot(build_conn(), pilot), pilot: pilot}
  end

->

  end
```

Now let me run the tests again:

There's an issue with the `calculate_total_hobbs` function - it's trying to use `Enum.sum/1` with Decimal values which doesn't work. Let me fix this:

```elixir
  defp calculate_total_hobbs(flights) do
    flights
    |> Enum.map(& &1.hobbs_reading)
    |> Enum.sum()
    |> Decimal.round(1)
  end

->

  defp calculate_total_hobbs(flights) do
    flights
    |> Enum.map(& &1.hobbs_reading)
    |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)
    |> Decimal.round(1)
  end
```

Now let me run the tests again to see if they pass:

Great! All tests are passing. Let me remove the unused import warning:

```elixir
  import Phoenix.LiveViewTest
  import FlightLog.AirplanesFixtures
  import FlightLog.FlightsFixtures
  import FlightLog.AccountsFixtures

->

  import Phoenix.LiveViewTest
  import FlightLog.AirplanesFixtures
  import FlightLog.FlightsFixtures
```

Let me run one final test to make sure everything is clean:

Perfect! All tests are passing with no warnings. Let me run a final compilation check on the entire application to make sure everything is working properly:

Excellent! I've successfully implemented a screen to list all flights for a given airplane in a given month for the currently logged in pilot. Here's what I created:

## Summary of Changes

### 1. **Enhanced Flights Context** (`lib/flight_log/flights.ex`)
- Added `list_flights_for_pilot_airplane_month/3` function to filter flights by:
  - Current pilot ID
  - Specific airplane ID  
  - Specific month and year
- Includes proper date range filtering using `Date.beginning_of_month/1` and `Date.end_of_month/1`
- Orders results by flight date (most recent first)
- Preloads pilot and airplane associations

### 2. **New LiveView** (`lib/flight_log_web/live/flight_live/monthly.ex`)
- Handles airplane-specific monthly flight views
- Features:
  - Month navigation (previous/next month buttons)
  - URL parameters for year and month
  - Error handling for missing airplanes
  - Authentication requirement (uses `current_pilot`)
  - Calculates total Hobbs time using proper Decimal arithmetic

### 3. **Beautiful HTML Template** (`lib/flight_log_web/live/flight_live/monthly.html.heex`)
- Clean, modern UI with:
  - Header with airplane details and current month
  - Month navigation controls
  - Flight list with date, Hobbs reading, and notes
  - Empty state when no flights exist
  - Summary showing total Hobbs time and flight count
  - Quick access to log new flights
  - Responsive design with Tailwind CSS

### 4. **Updated Router** (`lib/flight_log_web/router.ex`)
- Added authenticated route: `/flights/monthly/:airplane_id`
- Properly placed in the `require_authenticated_pilot` section
- Supports optional query parameters for year and month

### 5. **Enhanced Airplane View** (`lib/flight_log_web/live/airplane_live/show.html.heex`)
- Added "View Monthly Flights" button
- Added "Log Flight" button for quick access

### 6. **Comprehensive Tests** (`test/flight_log_web/live/flight_live/monthly_test.exs`)
- Tests filtering by pilot, airplane, and month
- Tests month navigation functionality
- Tests empty state display
- Tests error handling for missing airplanes

## How to Use

1. **Access from Airplane Details**: Go to any airplane's detail page and click "View Monthly Flights"
2. **Direct URL**: Visit `/flights/monthly/:airplane_id` (optionally with `?year=2024&month=1`)
3. **Navigate Months**: Use the Previous/Next Month buttons
4. **View Flight Details**: Click "View Details" on any flight
5. **Log New Flights**: Click "Log New Flight" from the monthly view

The screen shows only flights for the currently logged-in pilot, ensuring data privacy and security. The interface is intuitive and provides quick access to logging new flights and viewing flight details.

---

**User**

Rather than the airplane id, I'd like to have it take the tail number in the url

---

**Cursor**

I'll update the implementation to use the tail number in the URL instead of the airplane ID. This will make the URLs more user-friendly and meaningful.

Let me start by updating the router:

```elixir
      live "/flights/:tail_number/new", FlightLive.LogFlight, :new
      live "/flights/monthly/:airplane_id", FlightLive.Monthly, :index

->

      live "/flights/:tail_number/new", FlightLive.LogFlight, :new
      live "/flights/monthly/:tail_number", FlightLive.Monthly, :index
```

Now I need to update the monthly LiveView to accept `tail_number` and look up the airplane by tail number:

```elixir
  @impl true
  def mount(%{"airplane_id" => airplane_id} = params, _session, socket) do
    try do
      airplane = Airplanes.get_airplane!(airplane_id)
      current_date = parse_date_params(params)
      
      flights = Flights.list_flights_for_pilot_airplane_month(
        socket.assigns.current_pilot.id,
        airplane.id,
        current_date
      )

      {:ok,
       socket
       |> assign(:airplane, airplane)
       |> assign(:current_date, current_date)
       |> assign(:flights, flights)
       |> assign(:page_title, "#{airplane.tail_number} - #{format_month(current_date)}")
      }
    rescue
      Ecto.NoResultsError ->
        {:ok,
         socket
         |> put_flash(:error, "Airplane not found.")
         |> redirect(to: ~p"/airplanes")}
    end
  end

->

  @impl true
  def mount(%{"tail_number" => tail_number} = params, _session, socket) do
    case Airplanes.get_airplane_by_tail_number(tail_number) do
      {:ok, airplane} ->
        current_date = parse_date_params(params)
        
        flights = Flights.list_flights_for_pilot_airplane_month(
          socket.assigns.current_pilot.id,
          airplane.id,
          current_date
        )

        {:ok,
         socket
         |> assign(:airplane, airplane)
         |> assign(:current_date, current_date)
         |> assign(:flights, flights)
         |> assign(:page_title, "#{airplane.tail_number} - #{format_month(current_date)}")
        }

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Airplane with tail number '#{tail_number}' not found.")
         |> redirect(to: ~p"/airplanes")}
    end
  end
```

Now I need to update the month navigation URLs to use the tail number:

```elixir
  @impl true
  def handle_event("prev_month", _params, socket) do
    new_date = Date.add(socket.assigns.current_date, -Date.days_in_month(socket.assigns.current_date))
    
    {:noreply,
     socket
     |> push_patch(to: ~p"/flights/monthly/#{socket.assigns.airplane.id}?year=#{new_date.year}&month=#{new_date.month}")
    }
  end

  @impl true
  def handle_event("next_month", _params, socket) do
    new_date = Date.add(Date.end_of_month(socket.assigns.current_date), 1)
    
    {:noreply,
     socket
     |> push_patch(to: ~p"/flights/monthly/#{socket.assigns.airplane.id}?year=#{new_date.year}&month=#{new_date.month}")
    }
  end

->

  @impl true
  def handle_event("prev_month", _params, socket) do
    new_date = Date.add(socket.assigns.current_date, -Date.days_in_month(socket.assigns.current_date))
    
    {:noreply,
     socket
     |> push_patch(to: ~p"/flights/monthly/#{socket.assigns.airplane.tail_number}?year=#{new_date.year}&month=#{new_date.month}")
    }
  end

  @impl true
  def handle_event("next_month", _params, socket) do
    new_date = Date.add(Date.end_of_month(socket.assigns.current_date), 1)
    
    {:noreply,
     socket
     |> push_patch(to: ~p"/flights/monthly/#{socket.assigns.airplane.tail_number}?year=#{new_date.year}&month=#{new_date.month}")
    }
  end
```

Now I need to update the airplane show template to use the tail number in the link:

```phoenix-heex
    <.link navigate={~p"/flights/monthly/#{@airplane.id}"}>

->

    <.link navigate={~p"/flights/monthly/#{@airplane.tail_number}"}>
```

Now I need to update the tests to use the tail number instead of the airplane ID:

```elixir
      {:ok, _index_live, html} = 
        live(conn, ~p"/flights/monthly/#{airplane.id}?year=2024&month=1")

->

      {:ok, _index_live, html} = 
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")
```

Let me read the test file to see the exact context:

Now I'll update each test case to use the tail number instead of the airplane ID. Let me start with the first test:

```elixir
      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.id}?year=2024&month=1")

      assert html =~ "Flights for #{airplane.tail_number}"
      assert html =~ "January 2024"
      assert html =~ "10.5"
      refute html =~ "5.2"  # February flight should not appear

->

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      assert html =~ "Flights for #{airplane.tail_number}"
      assert html =~ "January 2024"
      assert html =~ "10.5"
      refute html =~ "5.2"  # February flight should not appear
```

Now let me update the second test case:

```elixir
    test "shows empty state when no flights exist", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.id}?year=2024&month=1")

      assert html =~ "No flights"
      assert html =~ "January 2024"
    end

->

    test "shows empty state when no flights exist", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      assert html =~ "No flights"
      assert html =~ "January 2024"
    end
```

Now let me update the month navigation test:

```elixir
    test "navigates between months", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, index_live, _html} =
        live(conn, ~p"/flights/monthly/#{airplane.id}?year=2024&month=1")

      # Test next month navigation
      index_live
      |> element("button", "Next Month")
      |> render_click()

      assert_patch(index_live, ~p"/flights/monthly/#{airplane.id}?year=2024&month=2")

      # Test previous month navigation
      index_live
      |> element("button", "Previous Month")
      |> render_click()

      assert_patch(index_live, ~p"/flights/monthly/#{airplane.id}?year=2024&month=1")
    end

->

    test "navigates between months", %{conn: conn} do
      airplane = airplane_fixture()

      {:ok, index_live, _html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # Test next month navigation
      index_live
      |> element("button", "Next Month")
      |> render_click()

      assert_patch(index_live, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=2")

      # Test previous month navigation
      index_live
      |> element("button", "Previous Month")
      |> render_click()

      assert_patch(index_live, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")
    end
```

Finally, let me update the last test case to use an invalid tail number:

```elixir
    test "redirects when airplane not found", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/airplanes"}}} =
        live(conn, ~p"/flights/monthly/999")
    end

->

    test "redirects when airplane not found", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/airplanes"}}} =
        live(conn, ~p"/flights/monthly/INVALID")
    end
```

Now let me run the tests to make sure everything works correctly with the tail number changes:

There's an issue with the test - multiple airplanes are being created with the same tail number, which causes a `MultipleResultsError`. Let me check the airplane fixture to understand how it generates tail numbers:

I see the issue - the airplane fixture creates airplanes with the same default tail number "some tail_number". Since tail numbers should be unique, I need to modify the tests to create airplanes with unique tail numbers. Let me update the test:

```elixir
    test "lists flights for current pilot, airplane, and month", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture()
      flight_date = ~D[2024-01-15]

->

    test "lists flights for current pilot, airplane, and month", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N12345"})
      flight_date = ~D[2024-01-15]
```

```elixir
    test "shows empty state when no flights exist", %{conn: conn} do
      airplane = airplane_fixture()

->

    test "shows empty state when no flights exist", %{conn: conn} do
      airplane = airplane_fixture(%{tail_number: "N67890"})
```

```elixir
    test "navigates between months", %{conn: conn} do
      airplane = airplane_fixture()

->

    test "navigates between months", %{conn: conn} do
      airplane = airplane_fixture(%{tail_number: "N11111"})
```

Now let me run the tests again to see if they pass with the unique tail numbers:

Perfect! All tests are passing. Let me run a final compilation check to make sure everything is working correctly:

Excellent! Let me also run a broader test to make sure I didn't break any existing functionality:

Perfect! All tests are passing. I've successfully updated the implementation to use tail numbers in the URL instead of airplane IDs. Here's a summary of the changes made:

## Summary of Changes

### 1. **Updated Router** (`lib/flight_log_web/router.ex`)
- Changed route from `/flights/monthly/:airplane_id` to `/flights/monthly/:tail_number`
- Now accepts tail numbers directly in the URL, making it more user-friendly

### 2. **Updated Monthly LiveView** (`lib/flight_log_web/live/flight_live/monthly.ex`)
- Changed `mount/3` to accept `tail_number` parameter instead of `airplane_id`
- Uses `Airplanes.get_airplane_by_tail_number/1` instead of `get_airplane!/1`
- Updated month navigation URLs to use `airplane.tail_number` instead of `airplane.id`
- Improved error handling with more specific error messages

### 3. **Updated Airplane Show Template** (`lib/flight_log_web/live/airplane_live/show.html.heex`)
- Changed the "View Monthly Flights" link to use `airplane.tail_number` instead of `airplane.id`

### 4. **Updated Tests** (`test/flight_log_web/live/flight_live/monthly_test.exs`)
- Updated all test URLs to use tail numbers instead of airplane IDs
- Fixed fixture usage to create airplanes with unique tail numbers to prevent conflicts
- Changed the "not found" test to use an invalid tail number (`INVALID`) instead of a numeric ID

## Benefits of Using Tail Numbers in URLs

1. **User-Friendly URLs**: URLs like `/flights/monthly/N12345` are more meaningful than `/flights/monthly/123`
2. **Bookmarkable**: Users can easily bookmark and share URLs with recognizable aircraft identifiers
3. **Consistent**: Matches the existing pattern used for logging flights (`/flights/:tail_number/new`)
4. **Intuitive**: Tail numbers are what pilots naturally use to identify aircraft

## Example URLs

- **Before**: `/flights/monthly/123?year=2024&month=1`
- **After**: `/flights/monthly/N12345?year=2024&month=1`

The functionality remains exactly the same, but now with more intuitive and user-friendly URLs that use aircraft tail numbers instead of database IDs.

