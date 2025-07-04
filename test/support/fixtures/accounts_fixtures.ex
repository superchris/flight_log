defmodule FlightLog.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FlightLog.Accounts` context.
  """

  def unique_pilot_email, do: "pilot#{System.unique_integer()}@example.com"
  def valid_pilot_password, do: "hello world!"

  def valid_pilot_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_pilot_email(),
      password: valid_pilot_password()
    })
  end

  def pilot_fixture(attrs \\ %{}) do
    {:ok, pilot} =
      attrs
      |> valid_pilot_attributes()
      |> FlightLog.Accounts.register_pilot()

    pilot
  end

  def extract_pilot_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
