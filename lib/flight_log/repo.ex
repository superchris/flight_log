defmodule FlightLog.Repo do
  use Ecto.Repo,
    otp_app: :flight_log,
    adapter: Ecto.Adapters.Postgres
end
