# FlightLog

## Dev container

With Docker and a dev-container compatible editor installed, open this repository and choose
**Reopen in Container**. The container uses mise to install Erlang, Elixir, and Node.js from
`mise.toml`, then installs the Mix dependencies, creates and migrates the PostgreSQL database,
and builds the assets automatically. The first setup can take a while if Erlang needs to be
compiled from source.

The tools are available in container terminals and editor tasks. To change versions, edit
`mise.toml` and run `mise install`. After changing the dev-container configuration, choose
**Dev Containers: Rebuild Container** to apply it.

Start the application from the container terminal:

```sh
mix phx.server
```

The app is available at [`localhost:4000`](http://localhost:4000). PostgreSQL data is kept in a
named Docker volume, so it survives container rebuilds.

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Creating a Pilot from IEx

To create a new pilot from the IEx console:

```elixir
FlightLog.Accounts.register_pilot(%{
  email: "pilot@example.com",
  password: "your_password_here",
  first_name: "John",
  last_name: "Doe"
})
```

Note: The password must be at least 12 characters long.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
