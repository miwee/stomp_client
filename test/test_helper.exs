ExUnit.start()

defmodule StompClientTest.Config do
  def host do
    System.get_env("STOMP_HOST") || "localhost"
  end

  def port do
    {port, _} = (System.get_env("STOMP_PORT") || "61613") |> Integer.parse()
    port
  end

  def login do
    "guest"
  end

  def passcode do
    "guest"
  end

  def connect_timeout do
    10_000
  end

  def connect_opts do
    [host: host, port: port, login: login, passcode: passcode]
  end
end
