defmodule StompClient.DefaultCallbackHandler do
  use GenServer
  require Logger

  def start_link(initial_state \\ []) do
    GenServer.start_link(__MODULE__, initial_state)
  end

  # GenServer callbacks
  def init(_initial_state) do
    {:ok, nil}
  end

  def handle_info({:stomp_client, :on_connect, message}, state) do
    Logger.info("stomp_client connected: #{inspect(message)}")
    {:noreply, state}
  end

  def handle_info({:stomp_client, :on_connect_error, message}, state) do
    Logger.info("stomp_client connection failure: #{inspect(message)}")
    {:noreply, state}
  end

  def handle_info({:stomp_client, :on_disconnect, true}, state) do
    Logger.info("stomp_client confirmation received for disconnection")
    {:noreply, state}
  end

  def handle_info({:stomp_client, :on_disconnect, false}, state) do
    Logger.info("stomp_client connection closed by remote host")
    {:noreply, state}
  end

  def handle_info({:stomp_client, :on_message, message}, state) do
    Logger.info("stomp_client message received: #{inspect(message, binaries: :as_strings)}")
    {:noreply, state}
  end

  def handle_info({:stomp_client, :on_receipt, receipt_id}, state) do
    Logger.info("stomp_client confirmation received: #{inspect(receipt_id)}")
    {:noreply, state}
  end

  def handle_info({:stomp_client, :on_send, {type, message}}, state) do
    Logger.info("stomp_client sending #{type}: #{inspect(message, binaries: :as_strings)}")
    {:noreply, state}
  end
end
