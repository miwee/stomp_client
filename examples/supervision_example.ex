defmodule SupervisionExample do
  use GenServer
  require Logger

  defmodule State do
    defstruct c: nil 
  end

  def start_link(connect_opts) do
    GenServer.start_link(__MODULE__, connect_opts, name: __MODULE__)
  end

  def init(connect_opts) do
    Process.send_after(self(), {:initial_connect, connect_opts}, 0)
    {:ok, %{}}
  end

  # GenServer callbacks
  def handle_info({:initial_connect, connect_opts}, state) do
    c = StompClient.connect(connect_opts, callback_handler: self())
    {:noreply, %{c: c}}
  end

  def handle_info({:stomp_client, :on_connect, message}, state) do
    Logger.info "stomp_client connected: #{inspect(message)}"
    {:noreply, state}
  end

  def handle_info({:stomp_client, :on_connect_error, message}, state) do
    Logger.info "stomp_client connection failure: #{inspect(message)}"
    {:noreply, state}
  end

  def handle_info({:stomp_client, :on_disconnect, true}, state) do
    Logger.info "stomp_client confirmation received for disconnection"
    {:noreply, state}
  end
  def handle_info({:stomp_client, :on_disconnect, false}, state) do
    Logger.info "stomp_client connection closed by remote host"
    {:noreply, state}
  end

  def handle_info({:stomp_client, :on_message, message}, state) do
    Logger.info "stomp_client message received: #{inspect(message, binaries: :as_strings)}"
    {:noreply, state}
  end

  def handle_info({:stomp_client, :on_receipt, receipt_id}, state) do
    Logger.info "stomp_client confirmation received: #{inspect(receipt_id)}"
    {:noreply, state}
  end

  def handle_info({:stomp_client, :on_send, {type, message}}, state) do
    Logger.info "stomp_client sending #{type}: #{inspect(message, binaries: :as_strings)}"
    {:noreply, state}
  end
end

defmodule SupervisionExample.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    connect_opts = [host: "127.0.0.1"]

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: Worker.start_link(arg1, arg2, arg3)
      # worker(Worker, [arg1, arg2, arg3]),
      worker(SupervisionExample, [connect_opts]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    supervise(children, strategy: :one_for_one)
  end
end
