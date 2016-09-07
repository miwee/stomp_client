# StompClient
STOMP client for Elixir with broker specific addons

## Usage

Please ensure you have a running STOMP compatible broker like RabbitMQ.

Add StompClient to your project dependencies in `mix.exs`

```elixir
def deps do
  [ {:stomp_client, github: "miwee/stomp_client"} ]
end
```

Refer to folder lib/stomp_client/rabbitmq for broker specific addons.

Refer to file lib/stomp_client/default_callback_handler.ex, for integrating the client within your code.

Load the project in `iex -S mix` to explore the StompClient

```
iex(1)> {:ok, pid} = StompClient.DefaultCallbackHandler.start_link(%{})
{:ok, #PID<0.83.0>}

iex(2)> options = [host: "localhost", port: 61613, login: "guest", passcode: "guest"]
[host: "localhost", port: 61613, login: "guest", passcode: "guest"]

iex(3)> c = StompClient.connect(options, callback_handler: pid)
#PID<0.86.0>

15:24:52.824 [info]  stomp_client connected: %{"heart-beat" => "0,0", "server" => "RabbitMQ/3.6.2", "session" => "session-2S-zfEuZZgh11CNikItXDw", "version" => "1.2"}

iex(4)> StompClient.subscribe(c, "test_topic", id: 1)
:ok

15:25:04.976 [info]  stomp_client sending SUBSCRIBE: "SUBSCRIBE\nid:1\ndestination:test_topic\nid:1\nack:auto\n\n\0"

iex(5)> StompClient.send(c, "test_topic", "some sample test data")
:ok

15:25:17.515 [info]  stomp_client sending SEND: "SEND\ndestination:test_topic\ncontent-length:21\n\nsome sample test data\0"

15:25:17.565 [info]  stomp_client message received: %{"body" => "some sample test data", "content-length" => "21", "destination" => "/queue/test_topic", "message-id" => "T_1@@session-2S-zfEuZZgh11CNikItXDw@@1", "redelivered" => "false", "subscription" => "1"}

```