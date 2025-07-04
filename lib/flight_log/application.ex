defmodule FlightLog.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FlightLogWeb.Telemetry,
      FlightLog.Repo,
      {DNSCluster, query: Application.get_env(:flight_log, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FlightLog.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: FlightLog.Finch},
      # Start a worker by calling: FlightLog.Worker.start_link(arg)
      # {FlightLog.Worker, arg},
      # Start to serve requests, typically the last entry
      FlightLogWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FlightLog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FlightLogWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
