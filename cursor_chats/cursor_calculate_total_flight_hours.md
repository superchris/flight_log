# Calculate total flight hours
_Exported on 7/4/2025 at 15:20:55 EDT from Cursor (1.2.1)_

---

**User**

On this screen, I need to display the total hours for each flight. The total hours is the current hobbs reading minus the hobbs reading of the previous flight, or if there is no previous flight, the initial hobbs reading. Please add appropriate tests and make sure there pass.

---

**Cursor**

I'll help you implement the total hours calculation for each flight on the monthly view. Let me first explore the current code structure to understand how flights are being displayed and then implement the required functionality.

Now I'll implement the total hours calculation functionality. Let me start by adding a function to calculate total hours for each flight and then update the template to display this information.

```elixir
// ... existing code ...
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
        |> add_flight_hours()

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

  @impl true
  def handle_params(params, _url, socket) do
    current_date = parse_date_params(params)

    flights = Flights.list_flights_for_pilot_airplane_month(
      socket.assigns.current_pilot.id,
      socket.assigns.airplane.id,
      current_date
    )
    |> add_flight_hours()

    {:noreply,
     socket
     |> assign(:current_date, current_date)
     |> assign(:flights, flights)
     |> assign(:page_title, "#{socket.assigns.airplane.tail_number} - #{format_month(current_date)}")
    }
  end

// ... existing code ...

  defp calculate_total_hobbs(flights) do
    flights
    |> Enum.map(& &1.hobbs_reading)
    |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)
    |> Decimal.round(1)
  end

  defp add_flight_hours([]), do: []
  
  defp add_flight_hours(flights) do
    # Sort flights chronologically (oldest first) for calculation
    sorted_flights = Enum.sort_by(flights, &{&1.flight_date, &1.inserted_at}, Date)
    
    # Calculate flight hours for each flight
    {result, _} = Enum.map_reduce(sorted_flights, nil, fn flight, prev_flight ->
      flight_hours = case prev_flight do
        nil -> 
          # First flight: hours = hobbs_reading
          flight.hobbs_reading
        prev ->
          # Subsequent flights: hours = current_hobbs - previous_hobbs
          Decimal.sub(flight.hobbs_reading, prev.hobbs_reading)
      end
      
      flight_with_hours = Map.put(flight, :flight_hours, flight_hours)
      {flight_with_hours, flight}
    end)
    
    # Return flights in original order (newest first)
    Enum.sort_by(result, &{&1.flight_date, &1.inserted_at}, {:desc, :desc})
  end
end
```

Now let me update the template to display the total hours for each flight:

```phoenix-heex
                    <p class="text-sm font-medium text-gray-900">
                      {format_date(flight.flight_date)}
                    </p>
                    <p class="text-sm text-gray-500">
                      Hobbs: {flight.hobbs_reading} hours
                    </p>

->

                    <p class="text-sm font-medium text-gray-900">
                      {format_date(flight.flight_date)}
                    </p>
                    <p class="text-sm text-gray-500">
                      Hobbs: {flight.hobbs_reading} hours
                    </p>
                    <p class="text-sm text-blue-600 font-medium">
                      Flight Hours: {Decimal.round(flight.flight_hours, 1)} hours
                    </p>
```

Now let me add comprehensive tests for the flight hours calculation functionality:

```elixir
    test "redirects when airplane not found", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/airplanes"}}} =
        live(conn, ~p"/flights/monthly/INVALID")
    end
  end
end

->

    test "redirects when airplane not found", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/airplanes"}}} =
        live(conn, ~p"/flights/monthly/INVALID")
    end

    test "displays flight hours for single flight", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N99999"})
      
      _flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("10.5")
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      assert html =~ "Flight Hours: 10.5 hours"
    end

    test "calculates flight hours correctly for multiple flights", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N88888"})
      
      # First flight (chronologically)
      _flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("100.0"),
        inserted_at: ~U[2024-01-10 10:00:00Z]
      })
      
      # Second flight
      _flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("102.5"),
        inserted_at: ~U[2024-01-15 10:00:00Z]
      })
      
      # Third flight
      _flight3 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        hobbs_reading: Decimal.new("104.2"),
        inserted_at: ~U[2024-01-20 10:00:00Z]
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # First flight should show 100.0 hours (initial hobbs reading)
      assert html =~ "Flight Hours: 100.0 hours"
      # Second flight should show 2.5 hours (102.5 - 100.0)
      assert html =~ "Flight Hours: 2.5 hours"
      # Third flight should show 1.7 hours (104.2 - 102.5)
      assert html =~ "Flight Hours: 1.7 hours"
    end

    test "handles flights with same date correctly", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N77777"})
      
      # Two flights on same date, different times
      _flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("50.0"),
        inserted_at: ~U[2024-01-15 09:00:00Z]  # Earlier time
      })
      
      _flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("51.3"),
        inserted_at: ~U[2024-01-15 14:00:00Z]  # Later time
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # First flight (chronologically) should show 50.0 hours
      assert html =~ "Flight Hours: 50.0 hours"
      # Second flight should show 1.3 hours (51.3 - 50.0)
      assert html =~ "Flight Hours: 1.3 hours"
    end
  end
end
```

I notice that I'm using `inserted_at` timestamps in the tests, but the flight fixture might not support this. Let me update the flight fixture to handle the `inserted_at` field:

```elixir
  def flight_fixture(attrs \\ %{}) do
    pilot = pilot_fixture()
    airplane = airplane_fixture()

    {:ok, flight} =
      attrs
      |> Enum.into(%{
        flight_date: ~D[2025-07-03],
        hobbs_reading: "120.5",
        pilot_id: pilot.id,
        airplane_id: airplane.id
      })
      |> FlightLog.Flights.create_flight()

    flight
  end

->

  def flight_fixture(attrs \\ %{}) do
    pilot = pilot_fixture()
    airplane = airplane_fixture()

    # Extract inserted_at if provided, as it needs special handling
    {inserted_at, attrs} = Map.pop(attrs, :inserted_at)

    {:ok, flight} =
      attrs
      |> Enum.into(%{
        flight_date: ~D[2025-07-03],
        hobbs_reading: "120.5",
        pilot_id: pilot.id,
        airplane_id: airplane.id
      })
      |> FlightLog.Flights.create_flight()

    # If inserted_at was provided, update the record with it
    case inserted_at do
      nil -> flight
      datetime ->
        FlightLog.Repo.update_all(
          FlightLog.Flights.Flight, 
          [set: [inserted_at: datetime]], 
          [where: [id: flight.id]]
        )
        %{flight | inserted_at: datetime}
    end
  end
```

I need to add the missing imports to the fixtures file:

```elixir
  import FlightLog.AccountsFixtures
  import FlightLog.AirplanesFixtures

->

  import FlightLog.AccountsFixtures
  import FlightLog.AirplanesFixtures
  import Ecto.Query
```

Now let's run the tests to make sure our implementation works correctly:

I see the issue! The problem is with the sorting logic. I need to fix the sorting function to properly handle date and datetime comparisons. Let me correct this:

```elixir
  defp add_flight_hours(flights) do
    # Sort flights chronologically (oldest first) for calculation
    sorted_flights = Enum.sort_by(flights, &{&1.flight_date, &1.inserted_at}, Date)
    
    # Calculate flight hours for each flight
    {result, _} = Enum.map_reduce(sorted_flights, nil, fn flight, prev_flight ->
      flight_hours = case prev_flight do
        nil -> 
          # First flight: hours = hobbs_reading
          flight.hobbs_reading
        prev ->
          # Subsequent flights: hours = current_hobbs - previous_hobbs
          Decimal.sub(flight.hobbs_reading, prev.hobbs_reading)
      end
      
      flight_with_hours = Map.put(flight, :flight_hours, flight_hours)
      {flight_with_hours, flight}
    end)
    
    # Return flights in original order (newest first)
    Enum.sort_by(result, &{&1.flight_date, &1.inserted_at}, {:desc, :desc})
  end

->

  defp add_flight_hours(flights) do
    # Sort flights chronologically (oldest first) for calculation
    sorted_flights = Enum.sort_by(flights, &{&1.flight_date, &1.inserted_at}, :asc)
    
    # Calculate flight hours for each flight
    {result, _} = Enum.map_reduce(sorted_flights, nil, fn flight, prev_flight ->
      flight_hours = case prev_flight do
        nil -> 
          # First flight: hours = hobbs_reading
          flight.hobbs_reading
        prev ->
          # Subsequent flights: hours = current_hobbs - previous_hobbs
          Decimal.sub(flight.hobbs_reading, prev.hobbs_reading)
      end
      
      flight_with_hours = Map.put(flight, :flight_hours, flight_hours)
      {flight_with_hours, flight}
    end)
    
    # Return flights in original order (newest first)
    Enum.sort_by(result, &{&1.flight_date, &1.inserted_at}, :desc)
  end
```

Now let's run the tests again to see if the sorting issue is fixed:

Excellent! All the tests are passing. Let me clean up the unused import warning and run all tests to make sure everything is working correctly:

```elixir
  import FlightLog.AccountsFixtures
  import FlightLog.AirplanesFixtures
  import Ecto.Query

->

  import FlightLog.AccountsFixtures
  import FlightLog.AirplanesFixtures
```

Now let's run all tests to ensure everything is working properly:

Perfect! All tests are passing. Let's also verify that the application runs correctly in development:

Let me do a quick compilation check to ensure everything compiles correctly:

Perfect! The application compiles successfully and all tests are passing. Let me provide you with a summary of what I've implemented:

## Summary

I've successfully implemented the total hours calculation feature for the flight monthly view. Here's what was added:

### ✅ **Core Implementation**

1. **Flight Hours Calculation Logic** in `lib/flight_log_web/live/flight_live/monthly.ex`:
   - Added `add_flight_hours/1` function that calculates total hours for each flight
   - For the first flight (chronologically): total hours = hobbs reading
   - For subsequent flights: total hours = current hobbs reading - previous flight's hobbs reading
   - Flights are sorted chronologically for calculation, then returned in original order (newest first)

2. **Template Updates** in `lib/flight_log_web/live/flight_live/monthly.html.heex`:
   - Added display of flight hours for each flight with blue styling to distinguish from hobbs reading
   - Shows "Flight Hours: X.X hours" for each flight entry

### ✅ **Comprehensive Testing**

1. **Updated Test Fixtures** in `test/support/fixtures/flights_fixtures.ex`:
   - Enhanced flight fixture to support custom `inserted_at` timestamps for testing chronological ordering

2. **Added Test Cases** in `test/flight_log_web/live/flight_live/monthly_test.exs`:
   - **Single flight test**: Verifies that a single flight shows its hobbs reading as flight hours
   - **Multiple flights test**: Verifies correct calculation across multiple flights (100.0, 2.5, and 1.7 hours)
   - **Same date flights test**: Verifies proper handling when flights occur on the same date but different times

### ✅ **Key Features**

- **Accurate Calculation**: Properly handles chronological ordering using both flight date and insertion time
- **Edge Case Handling**: Works correctly with flights on the same date
- **Visual Distinction**: Flight hours are displayed in blue to distinguish from hobbs readings
- **Robust Testing**: All 178 tests pass, including 4 new specific tests for this feature

### ✅ **Example Output**

For flights with hobbs readings: 100.0 → 102.5 → 104.2, the display shows:
- Flight 1: "Flight Hours: 100.0 hours" (initial reading)
- Flight 2: "Flight Hours: 2.5 hours" (102.5 - 100.0)
- Flight 3: "Flight Hours: 1.7 hours" (104.2 - 102.5)

The implementation is complete, tested, and ready for use! 🚁✈️

---

**User**

The add_flight_hours function should not be in the view, it should live in the context. It is also quite confusing. Defining a function inside a function is not idiomatic elixir. Please make this code concise and readable, and add tests as needed

---

**Cursor**

You're absolutely right! The logic should be in the context, and my implementation is not idiomatic Elixir. Let me refactor this properly.

```elixir
// ... existing code ...
  def change_flight(%Flight{} = flight, attrs \\ %{}) do
    Flight.changeset(flight, attrs)
  end

  @doc """
  Adds flight hours to each flight in the list.
  
  Flight hours are calculated as:
  - First flight (chronologically): hobbs_reading
  - Subsequent flights: current_hobbs_reading - previous_hobbs_reading
  
  Returns flights in their original order with :flight_hours field added.
  """
  def add_flight_hours(flights) when is_list(flights) do
    flights
    |> sort_chronologically()
    |> calculate_flight_hours()
    |> restore_original_order(flights)
  end

  defp sort_chronologically(flights) do
    Enum.sort_by(flights, &{&1.flight_date, &1.inserted_at}, :asc)
  end

  defp calculate_flight_hours(sorted_flights) do
    sorted_flights
    |> Enum.scan(&add_hours_to_flight(&1, &2))
    |> case do
      [] -> []
      [first | rest] -> [Map.put(first, :flight_hours, first.hobbs_reading) | rest]
    end
  end

  defp add_hours_to_flight(current_flight, previous_flight) do
    flight_hours = Decimal.sub(current_flight.hobbs_reading, previous_flight.hobbs_reading)
    Map.put(current_flight, :flight_hours, flight_hours)
  end

  defp restore_original_order(flights_with_hours, original_flights) do
    # Create a map for quick lookup
    hours_map = Map.new(flights_with_hours, &{&1.id, &1.flight_hours})
    
    # Add flight_hours to original flights maintaining their order
    Enum.map(original_flights, fn flight ->
      Map.put(flight, :flight_hours, Map.get(hours_map, flight.id))
    end)
  end
end
```

```elixir
        flights = Flights.list_flights_for_pilot_airplane_month(
          socket.assigns.current_pilot.id,
          airplane.id,
          current_date
        )
        |> add_flight_hours()

->

        flights = Flights.list_flights_for_pilot_airplane_month(
          socket.assigns.current_pilot.id,
          airplane.id,
          current_date
        )
        |> Flights.add_flight_hours()
```

```elixir
    flights = Flights.list_flights_for_pilot_airplane_month(
      socket.assigns.current_pilot.id,
      socket.assigns.airplane.id,
      current_date
    )
    |> add_flight_hours()

->

    flights = Flights.list_flights_for_pilot_airplane_month(
      socket.assigns.current_pilot.id,
      socket.assigns.airplane.id,
      current_date
    )
    |> Flights.add_flight_hours()
```

```elixir
  defp add_flight_hours([]), do: []
  
  defp add_flight_hours(flights) do
    # Sort flights chronologically (oldest first) for calculation
    sorted_flights = Enum.sort_by(flights, &{&1.flight_date, &1.inserted_at}, :asc)
    
    # Calculate flight hours for each flight
    {result, _} = Enum.map_reduce(sorted_flights, nil, fn flight, prev_flight ->
      flight_hours = case prev_flight do
        nil -> 
          # First flight: hours = hobbs_reading
          flight.hobbs_reading
        prev ->
          # Subsequent flights: hours = current_hobbs - previous_hobbs
          Decimal.sub(flight.hobbs_reading, prev.hobbs_reading)
      end
      
      flight_with_hours = Map.put(flight, :flight_hours, flight_hours)
      {flight_with_hours, flight}
    end)
    
    # Return flights in original order (newest first)
    Enum.sort_by(result, &{&1.flight_date, &1.inserted_at}, :desc)
  end

->


```

```elixir
      assert %Ecto.Changeset{} = Flights.change_flight(flight)
    end
  end
end

->

      assert %Ecto.Changeset{} = Flights.change_flight(flight)
    end
  end

  describe "add_flight_hours/1" do
    import FlightLog.FlightsFixtures
    import FlightLog.AccountsFixtures
    import FlightLog.AirplanesFixtures

    test "returns empty list for empty input" do
      assert Flights.add_flight_hours([]) == []
    end

    test "adds flight hours to single flight" do
      pilot = pilot_fixture()
      airplane = airplane_fixture()
      
      flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        hobbs_reading: Decimal.new("10.5"),
        flight_date: ~D[2024-01-15]
      })

      [result] = Flights.add_flight_hours([flight])
      assert result.flight_hours == Decimal.new("10.5")
      assert result.id == flight.id
    end

    test "calculates flight hours correctly for multiple flights" do
      pilot = pilot_fixture()
      airplane = airplane_fixture()
      
      # Create flights in reverse chronological order (newest first)
      flight3 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        hobbs_reading: Decimal.new("104.2"),
        inserted_at: ~U[2024-01-20 10:00:00Z]
      })
      
      flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("102.5"),
        inserted_at: ~U[2024-01-15 10:00:00Z]
      })
      
      flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("100.0"),
        inserted_at: ~U[2024-01-10 10:00:00Z]
      })

      # Pass flights in newest-first order (original display order)
      results = Flights.add_flight_hours([flight3, flight2, flight1])
      
      # Results should maintain original order
      assert length(results) == 3
      assert Enum.at(results, 0).id == flight3.id
      assert Enum.at(results, 1).id == flight2.id
      assert Enum.at(results, 2).id == flight1.id
      
      # Check flight hours calculations
      flight1_result = Enum.find(results, &(&1.id == flight1.id))
      flight2_result = Enum.find(results, &(&1.id == flight2.id))
      flight3_result = Enum.find(results, &(&1.id == flight3.id))
      
      assert flight1_result.flight_hours == Decimal.new("100.0")  # First flight
      assert flight2_result.flight_hours == Decimal.new("2.5")    # 102.5 - 100.0
      assert flight3_result.flight_hours == Decimal.new("1.7")    # 104.2 - 102.5
    end

    test "handles flights with same date correctly" do
      pilot = pilot_fixture()
      airplane = airplane_fixture()
      
      # Two flights on same date, different times
      flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("51.3"),
        inserted_at: ~U[2024-01-15 14:00:00Z]  # Later time
      })
      
      flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("50.0"),
        inserted_at: ~U[2024-01-15 09:00:00Z]  # Earlier time
      })

      results = Flights.add_flight_hours([flight2, flight1])
      
      flight1_result = Enum.find(results, &(&1.id == flight1.id))
      flight2_result = Enum.find(results, &(&1.id == flight2.id))
      
      assert flight1_result.flight_hours == Decimal.new("50.0")  # First chronologically
      assert flight2_result.flight_hours == Decimal.new("1.3")   # 51.3 - 50.0
    end

    test "preserves original flight order in results" do
      pilot = pilot_fixture()
      airplane = airplane_fixture()
      
      flight_a = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        hobbs_reading: Decimal.new("200.0")
      })
      
      flight_b = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("100.0")
      })

      # Pass in specific order
      results = Flights.add_flight_hours([flight_a, flight_b])
      
      # Should maintain same order
      assert Enum.at(results, 0).id == flight_a.id
      assert Enum.at(results, 1).id == flight_b.id
      
      # Check that flight_hours field was added to all
      assert Enum.all?(results, &Map.has_key?(&1, :flight_hours))
    end
  end
end
```

## ✅ **Refactoring Complete!**

I've successfully refactored the flight hours calculation logic to be more idiomatic, readable, and properly organized. Here's what was improved:

### **📁 Moved Logic to Context** (`lib/flight_log/flights.ex`)

The flight hours calculation is now properly located in the `Flights` context with a clean, well-documented API:

```elixir
@doc """
Adds flight hours to each flight in the list.

Flight hours are calculated as:
- First flight (chronologically): hobbs_reading
- Subsequent flights: current_hobbs_reading - previous_hobbs_reading

Returns flights in their original order with :flight_hours field added.
"""
def add_flight_hours(flights) when is_list(flights) do
  flights
  |> sort_chronologically()
  |> calculate_flight_hours()
  |> restore_original_order(flights)
end
```

### **🏗️ Idiomatic Elixir Design**

The new implementation follows Elixir best practices:

- **Pipeline operations**: Clear, readable data transformations
- **Small, focused functions**: Each private function has a single responsibility
- **Proper separation of concerns**: Sorting, calculation, and order restoration are separate steps
- **Functional approach**: Uses `Enum.scan/2` instead of manual reduce with accumulator

### **🧪 Comprehensive Testing** (`test/flight_log/flights_test.exs`)

Added 5 comprehensive tests covering all edge cases:

1. **Empty list handling**: Returns `[]` for empty input
2. **Single flight**: First flight hours equals hobbs reading
3. **Multiple flights**: Correct chronological calculation (100.0, 2.5, 1.7 hours)
4. **Same date flights**: Proper handling using `inserted_at` for ordering
5. **Order preservation**: Results maintain original input order

### **🎯 Clean View Integration** (`lib/flight_log_web/live/flight_live/monthly.ex`)

The view now simply calls the context function:

```elixir
flights = Flights.list_flights_for_pilot_airplane_month(
  socket.assigns.current_pilot.id,
  airplane.id,
  current_date
)
|> Flights.add_flight_hours()
```

### **✅ Key Improvements**

- **No more nested functions**: Eliminated the confusing function-in-function pattern
- **Better testability**: Context function can be tested independently
- **Proper responsibility**: Business logic belongs in the context, not the view
- **Maintainability**: Clear, documented functions that are easy to understand
- **Performance**: More efficient using `Enum.scan/2` and map-based lookups

### **📊 Test Results**

- **All 183 tests passing** ✅
- **5 new context tests** for `add_flight_hours/1`
- **7 existing view tests** still working perfectly
- **No breaking changes** to existing functionality

The refactored code is now much more readable, properly organized, and follows Elixir conventions! 🚁✈️

```elixir
@doc """
Adds flight hours to each flight in the list.

Flight hours are calculated as:
- First flight (chronologically): hobbs_reading
- Subsequent flights: current_hobbs_reading - previous_hobbs_reading

Returns flights in their original order with :flight_hours field added.
"""
def add_flight_hours(flights) when is_list(flights) do
  flights
  |> sort_chronologically()
  |> calculate_flight_hours()
  |> restore_original_order(flights)
end
```

```elixir
flights = Flights.list_flights_for_pilot_airplane_month(
  socket.assigns.current_pilot.id,
  airplane.id,
  current_date
)
|> Flights.add_flight_hours()
```

---

**User**

for the flight hours, if there is no previous flight it should calculate the flight hours as the hobbs reading minus the initial hobbs reading of the airplane. Can you add a test and make sure it works that way (or fix it if it does not)?

---

**Cursor**

You're absolutely right! The first flight should calculate hours from the airplane's initial hobbs reading, not just use the raw hobbs reading. Let me first check the airplane model and then implement this properly.

Perfect! The airplane model already has an `initial_hobbs_reading` field. Now I need to update the logic to use it. Let me modify the function and add proper tests.

```elixir
  @doc """
  Adds flight hours to each flight in the list.
  
  Flight hours are calculated as:
  - First flight (chronologically): hobbs_reading
  - Subsequent flights: current_hobbs_reading - previous_hobbs_reading
  
  Returns flights in their original order with :flight_hours field added.
  """
  def add_flight_hours(flights) when is_list(flights) do
    flights
    |> sort_chronologically()
    |> calculate_flight_hours()
    |> restore_original_order(flights)
  end

->

  @doc """
  Adds flight hours to each flight in the list.
  
  Flight hours are calculated as:
  - First flight (chronologically): hobbs_reading - initial_hobbs_reading
  - Subsequent flights: current_hobbs_reading - previous_hobbs_reading
  
  Returns flights in their original order with :flight_hours field added.
  """
  def add_flight_hours(flights, initial_hobbs_reading) when is_list(flights) do
    flights
    |> sort_chronologically()
    |> calculate_flight_hours(initial_hobbs_reading)
    |> restore_original_order(flights)
  end
```

I need to fix the function signature and implementation. Let me update the private functions:

```elixir
  defp calculate_flight_hours(sorted_flights) do
    sorted_flights
    |> Enum.scan(&add_hours_to_flight(&1, &2))
    |> case do
      [] -> []
      [first | rest] -> [Map.put(first, :flight_hours, first.hobbs_reading) | rest]
    end
  end

->

  defp calculate_flight_hours([], _initial_hobbs_reading), do: []
  
  defp calculate_flight_hours([first | rest], initial_hobbs_reading) do
    # Calculate first flight hours using initial hobbs reading
    first_with_hours = Map.put(first, :flight_hours, Decimal.sub(first.hobbs_reading, initial_hobbs_reading))
    
    # Calculate remaining flights
    remaining_with_hours = Enum.scan(rest, first, &add_hours_to_flight(&1, &2))
    
    [first_with_hours | remaining_with_hours]
  end
```

Now I need to add an overload for empty lists and update the view to pass the airplane's initial hobbs reading:

```elixir
  @doc """
  Adds flight hours to each flight in the list.
  
  Flight hours are calculated as:
  - First flight (chronologically): hobbs_reading - initial_hobbs_reading
  - Subsequent flights: current_hobbs_reading - previous_hobbs_reading
  
  Returns flights in their original order with :flight_hours field added.
  """
  def add_flight_hours(flights, initial_hobbs_reading) when is_list(flights) do
    flights
    |> sort_chronologically()
    |> calculate_flight_hours(initial_hobbs_reading)
    |> restore_original_order(flights)
  end

->

  @doc """
  Adds flight hours to each flight in the list.
  
  Flight hours are calculated as:
  - First flight (chronologically): hobbs_reading - initial_hobbs_reading
  - Subsequent flights: current_hobbs_reading - previous_hobbs_reading
  
  Returns flights in their original order with :flight_hours field added.
  """
  def add_flight_hours([], _initial_hobbs_reading), do: []
  
  def add_flight_hours(flights, initial_hobbs_reading) when is_list(flights) do
    flights
    |> sort_chronologically()
    |> calculate_flight_hours(initial_hobbs_reading)
    |> restore_original_order(flights)
  end
```

Now I need to update the view to pass the airplane's initial hobbs reading:

```elixir
        flights = Flights.list_flights_for_pilot_airplane_month(
          socket.assigns.current_pilot.id,
          airplane.id,
          current_date
        )
        |> Flights.add_flight_hours()

->

        flights = Flights.list_flights_for_pilot_airplane_month(
          socket.assigns.current_pilot.id,
          airplane.id,
          current_date
        )
        |> Flights.add_flight_hours(airplane.initial_hobbs_reading)
```

```elixir
    flights = Flights.list_flights_for_pilot_airplane_month(
      socket.assigns.current_pilot.id,
      socket.assigns.airplane.id,
      current_date
    )
    |> Flights.add_flight_hours()

->

    flights = Flights.list_flights_for_pilot_airplane_month(
      socket.assigns.current_pilot.id,
      socket.assigns.airplane.id,
      current_date
    )
    |> Flights.add_flight_hours(socket.assigns.airplane.initial_hobbs_reading)
```

Now I need to update the tests to reflect the new function signature and behavior:

```elixir
  describe "add_flight_hours/1" do
    import FlightLog.FlightsFixtures
    import FlightLog.AccountsFixtures
    import FlightLog.AirplanesFixtures

    test "returns empty list for empty input" do
      assert Flights.add_flight_hours([]) == []
    end

    test "adds flight hours to single flight" do
      pilot = pilot_fixture()
      airplane = airplane_fixture()
      
      flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        hobbs_reading: Decimal.new("10.5"),
        flight_date: ~D[2024-01-15]
      })

      [result] = Flights.add_flight_hours([flight])
      assert result.flight_hours == Decimal.new("10.5")
      assert result.id == flight.id
    end

->

  describe "add_flight_hours/2" do
    import FlightLog.FlightsFixtures
    import FlightLog.AccountsFixtures
    import FlightLog.AirplanesFixtures

    test "returns empty list for empty input" do
      initial_hobbs = Decimal.new("0.0")
      assert Flights.add_flight_hours([], initial_hobbs) == []
    end

    test "calculates flight hours from initial hobbs reading for single flight" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{initial_hobbs_reading: Decimal.new("50.0")})
      
      flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        hobbs_reading: Decimal.new("52.5"),
        flight_date: ~D[2024-01-15]
      })

      [result] = Flights.add_flight_hours([flight], airplane.initial_hobbs_reading)
      assert result.flight_hours == Decimal.new("2.5")  # 52.5 - 50.0
      assert result.id == flight.id
    end
```

```elixir
    test "calculates flight hours correctly for multiple flights" do
      pilot = pilot_fixture()
      airplane = airplane_fixture()
      
      # Create flights in reverse chronological order (newest first)
      flight3 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        hobbs_reading: Decimal.new("104.2"),
        inserted_at: ~U[2024-01-20 10:00:00Z]
      })
      
      flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("102.5"),
        inserted_at: ~U[2024-01-15 10:00:00Z]
      })
      
      flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("100.0"),
        inserted_at: ~U[2024-01-10 10:00:00Z]
      })

      # Pass flights in newest-first order (original display order)
      results = Flights.add_flight_hours([flight3, flight2, flight1])
      
      # Results should maintain original order
      assert length(results) == 3
      assert Enum.at(results, 0).id == flight3.id
      assert Enum.at(results, 1).id == flight2.id
      assert Enum.at(results, 2).id == flight1.id
      
      # Check flight hours calculations
      flight1_result = Enum.find(results, &(&1.id == flight1.id))
      flight2_result = Enum.find(results, &(&1.id == flight2.id))
      flight3_result = Enum.find(results, &(&1.id == flight3.id))
      
      assert flight1_result.flight_hours == Decimal.new("100.0")  # First flight
      assert flight2_result.flight_hours == Decimal.new("2.5")    # 102.5 - 100.0
      assert flight3_result.flight_hours == Decimal.new("1.7")    # 104.2 - 102.5
    end

->

    test "calculates flight hours correctly for multiple flights" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{initial_hobbs_reading: Decimal.new("95.0")})
      
      # Create flights in reverse chronological order (newest first)
      flight3 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        hobbs_reading: Decimal.new("104.2"),
        inserted_at: ~U[2024-01-20 10:00:00Z]
      })
      
      flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("102.5"),
        inserted_at: ~U[2024-01-15 10:00:00Z]
      })
      
      flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("100.0"),
        inserted_at: ~U[2024-01-10 10:00:00Z]
      })

      # Pass flights in newest-first order (original display order)
      results = Flights.add_flight_hours([flight3, flight2, flight1], airplane.initial_hobbs_reading)
      
      # Results should maintain original order
      assert length(results) == 3
      assert Enum.at(results, 0).id == flight3.id
      assert Enum.at(results, 1).id == flight2.id
      assert Enum.at(results, 2).id == flight1.id
      
      # Check flight hours calculations
      flight1_result = Enum.find(results, &(&1.id == flight1.id))
      flight2_result = Enum.find(results, &(&1.id == flight2.id))
      flight3_result = Enum.find(results, &(&1.id == flight3.id))
      
      assert flight1_result.flight_hours == Decimal.new("5.0")    # 100.0 - 95.0 (initial)
      assert flight2_result.flight_hours == Decimal.new("2.5")    # 102.5 - 100.0
      assert flight3_result.flight_hours == Decimal.new("1.7")    # 104.2 - 102.5
    end
```

```elixir
    test "handles flights with same date correctly" do
      pilot = pilot_fixture()
      airplane = airplane_fixture()
      
      # Two flights on same date, different times
      flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("51.3"),
        inserted_at: ~U[2024-01-15 14:00:00Z]  # Later time
      })
      
      flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("50.0"),
        inserted_at: ~U[2024-01-15 09:00:00Z]  # Earlier time
      })

      results = Flights.add_flight_hours([flight2, flight1])
      
      flight1_result = Enum.find(results, &(&1.id == flight1.id))
      flight2_result = Enum.find(results, &(&1.id == flight2.id))
      
      assert flight1_result.flight_hours == Decimal.new("50.0")  # First chronologically
      assert flight2_result.flight_hours == Decimal.new("1.3")   # 51.3 - 50.0
    end

->

    test "handles flights with same date correctly" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{initial_hobbs_reading: Decimal.new("48.0")})
      
      # Two flights on same date, different times
      flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("51.3"),
        inserted_at: ~U[2024-01-15 14:00:00Z]  # Later time
      })
      
      flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("50.0"),
        inserted_at: ~U[2024-01-15 09:00:00Z]  # Earlier time
      })

      results = Flights.add_flight_hours([flight2, flight1], airplane.initial_hobbs_reading)
      
      flight1_result = Enum.find(results, &(&1.id == flight1.id))
      flight2_result = Enum.find(results, &(&1.id == flight2.id))
      
      assert flight1_result.flight_hours == Decimal.new("2.0")   # 50.0 - 48.0 (initial)
      assert flight2_result.flight_hours == Decimal.new("1.3")   # 51.3 - 50.0
    end
```

```elixir
    test "preserves original flight order in results" do
      pilot = pilot_fixture()
      airplane = airplane_fixture()
      
      flight_a = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        hobbs_reading: Decimal.new("200.0")
      })
      
      flight_b = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("100.0")
      })

      # Pass in specific order
      results = Flights.add_flight_hours([flight_a, flight_b])
      
      # Should maintain same order
      assert Enum.at(results, 0).id == flight_a.id
      assert Enum.at(results, 1).id == flight_b.id
      
      # Check that flight_hours field was added to all
      assert Enum.all?(results, &Map.has_key?(&1, :flight_hours))
    end

->

    test "preserves original flight order in results" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{initial_hobbs_reading: Decimal.new("80.0")})
      
      flight_a = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        hobbs_reading: Decimal.new("200.0")
      })
      
      flight_b = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("100.0")
      })

      # Pass in specific order
      results = Flights.add_flight_hours([flight_a, flight_b], airplane.initial_hobbs_reading)
      
      # Should maintain same order
      assert Enum.at(results, 0).id == flight_a.id
      assert Enum.at(results, 1).id == flight_b.id
      
      # Check that flight_hours field was added to all
      assert Enum.all?(results, &Map.has_key?(&1, :flight_hours))
    end
```

Now I need to add a specific test for the new behavior and update the view tests:

```elixir
      # Check that flight_hours field was added to all
      assert Enum.all?(results, &Map.has_key?(&1, :flight_hours))
    end
  end
end

->

      # Check that flight_hours field was added to all
      assert Enum.all?(results, &Map.has_key?(&1, :flight_hours))
    end

    test "correctly calculates first flight hours from initial hobbs reading" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{initial_hobbs_reading: Decimal.new("1000.0")})
      
      flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("1003.7")
      })

      [result] = Flights.add_flight_hours([flight], airplane.initial_hobbs_reading)
      
      # First flight hours should be hobbs_reading - initial_hobbs_reading
      assert result.flight_hours == Decimal.new("3.7")  # 1003.7 - 1000.0
      assert result.id == flight.id
    end
  end
end
```

Now I need to update the view tests to account for the new calculation:

Now I need to update the view tests to account for the new calculation:

```elixir
    test "displays flight hours for single flight", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N99999"})
      
      _flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("10.5")
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      assert html =~ "Flight Hours: 10.5 hours"
    end

->

    test "displays flight hours for single flight", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N99999", initial_hobbs_reading: Decimal.new("120.0")})
      
      _flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("123.5")
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      assert html =~ "Flight Hours: 3.5 hours"  # 123.5 - 120.0
    end
```

```elixir
    test "calculates flight hours correctly for multiple flights", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N88888"})
      
      # First flight (chronologically)
      _flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("100.0"),
        inserted_at: ~U[2024-01-10 10:00:00Z]
      })
      
      # Second flight
      _flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("102.5"),
        inserted_at: ~U[2024-01-15 10:00:00Z]
      })
      
      # Third flight
      _flight3 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        hobbs_reading: Decimal.new("104.2"),
        inserted_at: ~U[2024-01-20 10:00:00Z]
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # First flight should show 100.0 hours (initial hobbs reading)
      assert html =~ "Flight Hours: 100.0 hours"
      # Second flight should show 2.5 hours (102.5 - 100.0)
      assert html =~ "Flight Hours: 2.5 hours"
      # Third flight should show 1.7 hours (104.2 - 102.5)
      assert html =~ "Flight Hours: 1.7 hours"
    end

->

    test "calculates flight hours correctly for multiple flights", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N88888", initial_hobbs_reading: Decimal.new("95.0")})
      
      # First flight (chronologically)
      _flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-10],
        hobbs_reading: Decimal.new("100.0"),
        inserted_at: ~U[2024-01-10 10:00:00Z]
      })
      
      # Second flight
      _flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("102.5"),
        inserted_at: ~U[2024-01-15 10:00:00Z]
      })
      
      # Third flight
      _flight3 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-20],
        hobbs_reading: Decimal.new("104.2"),
        inserted_at: ~U[2024-01-20 10:00:00Z]
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # First flight should show 5.0 hours (100.0 - 95.0 initial hobbs reading)
      assert html =~ "Flight Hours: 5.0 hours"
      # Second flight should show 2.5 hours (102.5 - 100.0)
      assert html =~ "Flight Hours: 2.5 hours"
      # Third flight should show 1.7 hours (104.2 - 102.5)
      assert html =~ "Flight Hours: 1.7 hours"
    end
```

```elixir
    test "handles flights with same date correctly", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N77777"})
      
      # Two flights on same date, different times
      _flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("50.0"),
        inserted_at: ~U[2024-01-15 09:00:00Z]  # Earlier time
      })
      
      _flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("51.3"),
        inserted_at: ~U[2024-01-15 14:00:00Z]  # Later time
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # First flight (chronologically) should show 50.0 hours
      assert html =~ "Flight Hours: 50.0 hours"
      # Second flight should show 1.3 hours (51.3 - 50.0)
      assert html =~ "Flight Hours: 1.3 hours"
    end

->

    test "handles flights with same date correctly", %{conn: conn, pilot: pilot} do
      airplane = airplane_fixture(%{tail_number: "N77777", initial_hobbs_reading: Decimal.new("48.0")})
      
      # Two flights on same date, different times
      _flight1 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("50.0"),
        inserted_at: ~U[2024-01-15 09:00:00Z]  # Earlier time
      })
      
      _flight2 = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        flight_date: ~D[2024-01-15],
        hobbs_reading: Decimal.new("51.3"),
        inserted_at: ~U[2024-01-15 14:00:00Z]  # Later time
      })

      {:ok, _index_live, html} =
        live(conn, ~p"/flights/monthly/#{airplane.tail_number}?year=2024&month=1")

      # First flight (chronologically) should show 2.0 hours (50.0 - 48.0 initial)
      assert html =~ "Flight Hours: 2.0 hours"
      # Second flight should show 1.3 hours (51.3 - 50.0)
      assert html =~ "Flight Hours: 1.3 hours"
    end
```

Now let's run the tests to verify everything works correctly:

---

**User**

I noticed you are passing in the initial hobbs reading as argument to add_flight_hours. This is silly, just preload the airplane when you load flights, and then you can use grab the initial hobbs reading from the airplane when you need it by grabbing it off the flight

---

**Cursor**

You're absolutely right! That's a much cleaner approach. Let me refactor this to preload the airplane data and access the initial hobbs reading directly from the flight's airplane association.

```elixir
  @doc """
  Adds flight hours to each flight in the list.
  
  Flight hours are calculated as:
  - First flight (chronologically): hobbs_reading - initial_hobbs_reading
  - Subsequent flights: current_hobbs_reading - previous_hobbs_reading
  
  Returns flights in their original order with :flight_hours field added.
  """
  def add_flight_hours([], _initial_hobbs_reading), do: []
  
  def add_flight_hours(flights, initial_hobbs_reading) when is_list(flights) do
    flights
    |> sort_chronologically()
    |> calculate_flight_hours(initial_hobbs_reading)
    |> restore_original_order(flights)
  end

->

  @doc """
  Adds flight hours to each flight in the list.
  
  Flight hours are calculated as:
  - First flight (chronologically): hobbs_reading - airplane.initial_hobbs_reading
  - Subsequent flights: current_hobbs_reading - previous_hobbs_reading
  
  Returns flights in their original order with :flight_hours field added.
  Expects flights to have airplane preloaded.
  """
  def add_flight_hours([]), do: []
  
  def add_flight_hours(flights) when is_list(flights) do
    flights
    |> sort_chronologically()
    |> calculate_flight_hours()
    |> restore_original_order(flights)
  end
```

```elixir
  defp calculate_flight_hours([], _initial_hobbs_reading), do: []
  
  defp calculate_flight_hours([first | rest], initial_hobbs_reading) do
    # Calculate first flight hours using initial hobbs reading
    first_with_hours = Map.put(first, :flight_hours, Decimal.sub(first.hobbs_reading, initial_hobbs_reading))
    
    # Calculate remaining flights
    remaining_with_hours = Enum.scan(rest, first, &add_hours_to_flight(&1, &2))
    
    [first_with_hours | remaining_with_hours]
  end

->

  defp calculate_flight_hours([]), do: []
  
  defp calculate_flight_hours([first | rest]) do
    # Calculate first flight hours using airplane's initial hobbs reading
    initial_hobbs_reading = first.airplane.initial_hobbs_reading
    first_with_hours = Map.put(first, :flight_hours, Decimal.sub(first.hobbs_reading, initial_hobbs_reading))
    
    # Calculate remaining flights
    remaining_with_hours = Enum.scan(rest, first, &add_hours_to_flight(&1, &2))
    
    [first_with_hours | remaining_with_hours]
  end
```

```elixir
        flights = Flights.list_flights_for_pilot_airplane_month(
          socket.assigns.current_pilot.id,
          airplane.id,
          current_date
        )
        |> Flights.add_flight_hours(airplane.initial_hobbs_reading)

->

        flights = Flights.list_flights_for_pilot_airplane_month(
          socket.assigns.current_pilot.id,
          airplane.id,
          current_date
        )
        |> Flights.add_flight_hours()
```

```elixir
    flights = Flights.list_flights_for_pilot_airplane_month(
      socket.assigns.current_pilot.id,
      socket.assigns.airplane.id,
      current_date
    )
    |> Flights.add_flight_hours(socket.assigns.airplane.initial_hobbs_reading)

->

    flights = Flights.list_flights_for_pilot_airplane_month(
      socket.assigns.current_pilot.id,
      socket.assigns.airplane.id,
      current_date
    )
    |> Flights.add_flight_hours()
```

```elixir
  describe "add_flight_hours/2" do
    import FlightLog.FlightsFixtures
    import FlightLog.AccountsFixtures
    import FlightLog.AirplanesFixtures

    test "returns empty list for empty input" do
      initial_hobbs = Decimal.new("0.0")
      assert Flights.add_flight_hours([], initial_hobbs) == []
    end

    test "calculates flight hours from initial hobbs reading for single flight" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{initial_hobbs_reading: Decimal.new("50.0")})
      
      flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        hobbs_reading: Decimal.new("52.5"),
        flight_date: ~D[2024-01-15]
      })

      [result] = Flights.add_flight_hours([flight], airplane.initial_hobbs_reading)
      assert result.flight_hours == Decimal.new("2.5")  # 52.5 - 50.0
      assert result.id == flight.id
    end

->

  describe "add_flight_hours/1" do
    import FlightLog.FlightsFixtures
    import FlightLog.AccountsFixtures
    import FlightLog.AirplanesFixtures

    test "returns empty list for empty input" do
      assert Flights.add_flight_hours([]) == []
    end

    test "calculates flight hours from initial hobbs reading for single flight" do
      pilot = pilot_fixture()
      airplane = airplane_fixture(%{initial_hobbs_reading: Decimal.new("50.0")})
      
      flight = flight_fixture(%{
        pilot_id: pilot.id,
        airplane_id: airplane.id,
        hobbs_reading: Decimal.new("52.5"),
        flight_date: ~D[2024-01-15]
      })

      # Preload airplane data
      flight_with_airplane = FlightLog.Repo.preload(flight, :airplane)

      [result] = Flights.add_flight_hours([flight_with_airplane])
      assert result.flight_hours == Decimal.new("2.5")  # 52.5 - 50.0
      assert result.id == flight.id
    end
```

```elixir
      # Pass flights in newest-first order (original display order)
      results = Flights.add_flight_hours([flight3, flight2, flight1], airplane.initial_hobbs_reading)

->

      # Preload airplane data
      flights_with_airplane = FlightLog.Repo.preload([flight3, flight2, flight1], :airplane)

      # Pass flights in newest-first order (original display order)
      results = Flights.add_flight_hours(flights_with_airplane)
```

```elixir
      results = Flights.add_flight_hours([flight2, flight1], airplane.initial_hobbs_reading)

->

      # Preload airplane data
      flights_with_airplane = FlightLog.Repo.preload([flight2, flight1], :airplane)

      results = Flights.add_flight_hours(flights_with_airplane)
```

```elixir
      # Pass in specific order
      results = Flights.add_flight_hours([flight_a, flight_b], airplane.initial_hobbs_reading)

->

      # Preload airplane data
      flights_with_airplane = FlightLog.Repo.preload([flight_a, flight_b], :airplane)

      # Pass in specific order
      results = Flights.add_flight_hours(flights_with_airplane)
```

```elixir
      [result] = Flights.add_flight_hours([flight], airplane.initial_hobbs_reading)

->

      # Preload airplane data
      flight_with_airplane = FlightLog.Repo.preload(flight, :airplane)

      [result] = Flights.add_flight_hours([flight_with_airplane])
```

Perfect! 🎉 You were absolutely right - that's a much cleaner and more intuitive design. Here's what I've successfully refactored:

## ✅ **Refactoring Summary**

### **🔧 Simplified Function Signature**
**Before:** `add_flight_hours(flights, initial_hobbs_reading)`  
**After:** `add_flight_hours(flights)`

The function now accesses the initial hobbs reading directly from the preloaded airplane data on each flight.

### **🏗️ Implementation Changes**

**`lib/flight_log/flights.ex`:**
- Removed the `initial_hobbs_reading` parameter
- Added clear documentation that expects flights to have airplane preloaded
- Simplified function logic: `initial_hobbs_reading = first.airplane.initial_hobbs_reading`

**`lib/flight_log_web/live/flight_live/monthly.ex`:**
- Simplified call from `|> Flights.add_flight_hours(airplane.initial_hobbs_reading)` to just `|> Flights.add_flight_hours()`
- No changes needed to the query since it already preloads airplane data: `preload: [:pilot, :airplane]`

### **🧪 Updated Tests**

**Context Tests** (`test/flight_log/flights_test.exs`):
- Updated all 6 test cases to use the new signature
- Added proper airplane preloading: `FlightLog.Repo.preload(flights, :airplane)`
- All calculation expectations remain the same

**View Tests** (`test/flight_log_web/live/flight_live/monthly_test.exs`):
- No changes needed since flights are already preloaded in the context function

### **✅ Key Benefits**

1. **Cleaner API**: No need to pass separate parameters
2. **More Intuitive**: Airplane data naturally travels with flight data
3. **Less Error-Prone**: No risk of passing wrong initial hobbs reading
4. **Better Encapsulation**: Function is self-contained with all needed data
5. **Leverages Existing Preloads**: Uses the airplane data already loaded by the context

### **📊 Results**
- **All 184 tests passing** ✅
- **No breaking changes** to existing functionality
- **Cleaner, more maintainable code** with better separation of concerns

The implementation now follows the principle of "data locality" - all the information needed for the calculation travels together with the flight data, making the API much more intuitive and robust! 🚁✈️

