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

seed_pilot = %{
  email: "pilot@example.com",
  password: "password1234",
  first_name: "Seed",
  last_name: "Pilot"
}

case Accounts.get_pilot_by_email(seed_pilot.email) do
  nil ->
    {:ok, _pilot} = Accounts.register_pilot(seed_pilot)
    IO.puts("Created seed pilot: #{seed_pilot.email}")

  _pilot ->
    IO.puts("Seed pilot already exists: #{seed_pilot.email}")
end
