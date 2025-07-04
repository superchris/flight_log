defmodule FlightLogWeb.Router do
  use FlightLogWeb, :router

  import FlightLogWeb.PilotAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FlightLogWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_pilot
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FlightLogWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/airplanes", AirplaneLive.Index, :index
    live "/airplanes/new", AirplaneLive.Index, :new
    live "/airplanes/:id/edit", AirplaneLive.Index, :edit

    live "/airplanes/:id", AirplaneLive.Show, :show
    live "/airplanes/:id/show/edit", AirplaneLive.Show, :edit

    live "/flights", FlightLive.Index, :index
    live "/flights/new", FlightLive.Index, :new
    live "/flights/:id/edit", FlightLive.Index, :edit

    live "/flights/:id", FlightLive.Show, :show
    live "/flights/:id/show/edit", FlightLive.Show, :edit
  end

  # Other scopes may use custom stacks.
  # scope "/api", FlightLogWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:flight_log, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FlightLogWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", FlightLogWeb do
    pipe_through [:browser, :redirect_if_pilot_is_authenticated]

    live_session :redirect_if_pilot_is_authenticated,
      on_mount: [{FlightLogWeb.PilotAuth, :redirect_if_pilot_is_authenticated}] do
      live "/pilots/register", PilotRegistrationLive, :new
      live "/pilots/log_in", PilotLoginLive, :new
      live "/pilots/reset_password", PilotForgotPasswordLive, :new
      live "/pilots/reset_password/:token", PilotResetPasswordLive, :edit
    end

    post "/pilots/log_in", PilotSessionController, :create
  end

  scope "/", FlightLogWeb do
    pipe_through [:browser, :require_authenticated_pilot]

    live_session :require_authenticated_pilot,
      on_mount: [{FlightLogWeb.PilotAuth, :ensure_authenticated}] do
      live "/pilots/settings", PilotSettingsLive, :edit
      live "/pilots/settings/confirm_email/:token", PilotSettingsLive, :confirm_email
      live "/flights/:tail_number/new", FlightLive.LogFlight, :new
      live "/flights/monthly/:tail_number", FlightLive.Monthly, :index
    end
  end

  scope "/", FlightLogWeb do
    pipe_through [:browser]

    delete "/pilots/log_out", PilotSessionController, :delete

    live_session :current_pilot,
      on_mount: [{FlightLogWeb.PilotAuth, :mount_current_pilot}] do
      live "/pilots/confirm/:token", PilotConfirmationLive, :edit
      live "/pilots/confirm", PilotConfirmationInstructionsLive, :new
    end
  end
end
