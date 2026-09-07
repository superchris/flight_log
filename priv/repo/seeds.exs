# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     FlightLog.Repo.insert!(%FlightLog.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias FlightLog.Accounts
alias FlightLog.Airplanes

seed_pilot = %{
  email: "pilot@example.com",
  password: "password1234",
  first_name: "Seed",
  last_name: "Pilot"
}

pilot =
  case Accounts.get_pilot_by_email(seed_pilot.email) do
    nil ->
      {:ok, pilot} = Accounts.register_pilot(seed_pilot)
      IO.puts("Created seed pilot: #{seed_pilot.email}")
      pilot

    pilot ->
      IO.puts("Seed pilot already exists: #{seed_pilot.email}")
      pilot
  end

seed_airplane = %{
  make: "Piper",
  model: "Warrior",
  year: 1978,
  tail_number: "N47881",
  # The app currently stores starting meter hours in this field.
  initial_hobbs_reading: "7588.0"
}

airplane =
  case Airplanes.get_airplane_by_tail_number(seed_airplane.tail_number) do
    {:error, :not_found} ->
      {:ok, airplane} = Airplanes.create_airplane(seed_airplane)
      IO.puts("Created seed airplane: #{seed_airplane.tail_number}")
      airplane

    {:ok, airplane} ->
      IO.puts("Seed airplane already exists: #{seed_airplane.tail_number}")
      airplane
  end

unless Enum.any?(Airplanes.list_airplanes_for_pilot(pilot), &(&1.id == airplane.id)) do
  {:ok, _airplane} = Airplanes.add_pilot_to_airplane(airplane, pilot)
  IO.puts("Associated #{airplane.tail_number} with #{pilot.email}")
end
