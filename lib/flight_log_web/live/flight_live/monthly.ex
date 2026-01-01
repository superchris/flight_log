defmodule FlightLogWeb.FlightLive.Monthly do
  use FlightLogWeb, :live_view

  alias FlightLog.Flights
  alias FlightLog.Flights.Flight
  alias FlightLog.Airplanes
  alias FlightLog.Costs
  alias FlightLog.Repo

  import Ecto.Query, warn: false

    @impl true
  def mount(%{"tail_number" => tail_number} = params, _session, socket) do
    case Airplanes.get_airplane_by_tail_number(tail_number) do
      {:ok, airplane} ->
        airplane = Repo.preload(airplane, :pilots)
        current_date = parse_date_params(params)
        start_of_month = Date.beginning_of_month(current_date)

        previous_hobbs = Flights.get_previous_hobbs_reading(airplane.id, start_of_month)

        flights =
          Flights.list_flights_for_airplane_month(airplane.id, current_date)
          |> Flights.add_flight_hours(previous_hobbs)

        total_flight_hours = calculate_total_flight_hours(flights)
        costs = Costs.get_monthly_costs_for_airplane(airplane.id, current_date, total_flight_hours)

        flight = %Flight{airplane_id: airplane.id, pilot_id: socket.assigns.current_pilot.id}

        {:ok,
         socket
         |> assign(:airplane, airplane)
         |> assign(:current_date, current_date)
         |> assign(:flights, flights)
         |> assign(:costs, costs)
         |> assign(:page_title, "#{airplane.tail_number} - #{format_month(current_date)}")
         |> assign(:flight, flight)
         |> assign(:pilot_options, build_pilot_options(airplane.pilots))
         |> assign(:form, to_form(Flights.change_flight(flight)))}

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
    start_of_month = Date.beginning_of_month(current_date)

    previous_hobbs = Flights.get_previous_hobbs_reading(socket.assigns.airplane.id, start_of_month)

    flights =
      Flights.list_flights_for_airplane_month(socket.assigns.airplane.id, current_date)
      |> Flights.add_flight_hours(previous_hobbs)

    total_flight_hours = calculate_total_flight_hours(flights)
    costs = Costs.get_monthly_costs_for_airplane(socket.assigns.airplane.id, current_date, total_flight_hours)

    # Reset form for new flight
    flight = %Flight{airplane_id: socket.assigns.airplane.id, pilot_id: socket.assigns.current_pilot.id}

    {:noreply,
     socket
     |> assign(:current_date, current_date)
     |> assign(:flights, flights)
     |> assign(:costs, costs)
     |> assign(:page_title, "#{socket.assigns.airplane.tail_number} - #{format_month(current_date)}")
     |> assign(:flight, flight)
     |> assign(:form, to_form(Flights.change_flight(flight)))}
  end

    @impl true
  def handle_event("prev_month", _params, socket) do
    new_date = socket.assigns.current_date
               |> Date.beginning_of_month()
               |> Date.add(-1)

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

  @impl true
  def handle_event("validate", %{"flight" => flight_params}, socket) do
    changeset = Flights.change_flight(socket.assigns.flight, flight_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("save", %{"flight" => flight_params}, socket) do
    flight_params =
      flight_params
      |> Map.put("airplane_id", socket.assigns.airplane.id)

    case Flights.create_flight(flight_params) do
      {:ok, _flight} ->
        current_date = socket.assigns.current_date

        {:noreply,
         socket
         |> put_flash(:info, "Flight logged successfully!")
         |> push_navigate(to: ~p"/flights/monthly/#{socket.assigns.airplane.tail_number}?year=#{current_date.year}&month=#{current_date.month}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
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

  defp format_date(date) do
    Calendar.strftime(date, "%m/%d/%Y")
  end

  defp calculate_total_flight_hours(flights) do
    flights
    |> Enum.map(& &1.flight_hours)
    |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)
    |> Decimal.round(1)
  end

    defp group_flights_by_pilot(flights) do
    flights
    |> Enum.group_by(fn flight ->
      "#{flight.pilot.first_name} #{flight.pilot.last_name}"
    end)
    |> Enum.sort_by(fn {pilot_name, _flights} -> pilot_name end)
  end

  defp calculate_pilot_costs(costs, pilot_hours) do
    # Calculate hourly costs for this pilot's hours
    hourly_cost_per_hour =
      costs.hourly_costs
      |> Enum.map(& &1.amount)
      |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)

    pilot_hourly_cost = Decimal.mult(hourly_cost_per_hour, pilot_hours)

    # Monthly and one-time costs apply to all pilots (shared airplane costs)
    pilot_monthly_cost = costs.total_monthly_cost
    pilot_one_time_cost = costs.total_one_time_cost

    # Calculate total
    total_cost =
      [pilot_hourly_cost, pilot_monthly_cost, pilot_one_time_cost]
      |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)

    %{
      hourly_cost: pilot_hourly_cost,
      monthly_cost: pilot_monthly_cost,
      one_time_cost: pilot_one_time_cost,
      total_cost: total_cost
    }
  end

  defp build_pilot_options(pilots) do
    Enum.map(pilots, fn pilot ->
      display_name =
        case {pilot.first_name, pilot.last_name} do
          {nil, nil} -> pilot.email
          {first, nil} -> "#{first} (#{pilot.email})"
          {nil, last} -> "#{last} (#{pilot.email})"
          {first, last} -> "#{first} #{last} (#{pilot.email})"
        end

      {display_name, pilot.id}
    end)
  end
end
