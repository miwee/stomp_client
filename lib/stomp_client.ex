defmodule StompClient do
  @moduledoc """
  Provides a Client implementation that keeps a tcp connection using Genserver
  with CallbackHandler for messages sent and received.
  This module by design has no broker specific functionality.
  """

  use GenServer
  require Logger

  import Kernel, except: [send: 2]

  alias StompClient.Parser

  @default_vhost "/"
  @default_connection_timeout 10_000
  @default_heartbeat_interval 120_000
  @default_subscription_id 1

  defmodule State do
    defstruct callback_handler: nil,
              sock: nil,
              recv_buffer: "",
              logged_in: false,
              disconnect_id: nil
  end

  def start_link(initial_state \\ []) do
    GenServer.start_link(__MODULE__, initial_state)
  end

  def connect do
    connect([])
  end

  def connect(connect_opts) do
    connect(connect_opts, callback_handler: nil)
  end

  def connect(connect_opts, callback_handler: callback_handler) do
    {:ok, pid} = StompClient.start_link(callback_handler)
    timeout = Keyword.get(connect_opts, :timeout, @default_connection_timeout)
    GenServer.call(pid, {:connect, connect_opts}, timeout)
    pid
  end

  def send(pid, destination, body) do
    send(pid, destination, body, %{})
  end

  def send(pid, destination, body, opts) do
    GenServer.call(pid, {:send, destination, body, opts})
  end

  def subscribe(pid, destination, id: sub_id) do
    subscribe(pid, destination, id: sub_id, ack: "auto")
  end

  def subscribe(pid, destination, opts) do
    case Keyword.get(opts, :id, nil) do
      nil ->
        {:error, :id_field_missing}

      sub_id ->
        opts = Keyword.delete(opts, :id)
        GenServer.call(pid, {:subscribe, destination, sub_id, opts})
    end
  end

  def unsubscribe(pid, destination) do
    unsubscribe(pid, destination, [])
  end

  def unsubscribe(pid, destination, opts) do
    GenServer.call(pid, {:unsubscribe, destination, opts})
  end

  def ack(pid, message_id) do
    GenServer.call(pid, {:ack, message_id})
  end

  def nack(pid, message_id) do
    GenServer.call(pid, {:nack, message_id})
  end

  def begin_transaction(pid, transaction_id) do
    GenServer.call(pid, {:begin_transaction, transaction_id})
  end

  def commit_transaction(pid, transaction_id) do
    GenServer.call(pid, {:commit_transaction, transaction_id})
  end

  def abort_transaction(pid, transaction_id) do
    GenServer.call(pid, {:abort_transaction, transaction_id})
  end

  def ack_transaction(pid, message_id, transaction_id) do
    GenServer.call(pid, {:ack, message_id, transaction_id})
  end

  def nack_transaction(pid, message_id, transaction_id) do
    GenServer.call(pid, {:nack, message_id, transaction_id})
  end

  def disconnect(pid) do
    GenServer.call(pid, :disconnect)
  end

  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  ## GenServer callback_handlers
  def init(callback_handler) do
    {:ok, %State{callback_handler: callback_handler}}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call({:connect, opts}, _from, state) do
    host = Keyword.get(opts, :host, "127.0.0.1")
    port = Keyword.get(opts, :port, 61613)
    login = Keyword.get(opts, :login, nil)
    passcode = Keyword.get(opts, :passcode, nil)
    version = Keyword.get(opts, :version, "1.2")
    vhost = Keyword.get(opts, :vhost, @default_vhost)
    timeout = Keyword.get(opts, :timeout, @default_connection_timeout)
    # heartbeat = Keyword.get(opts, :heartbeat, @default_heartbeat_interval)

    tcp_opts = [:binary, {:active, :once}]
    host = to_charlist(host)

    case :gen_tcp.connect(host, port, tcp_opts, timeout) do
      {:ok, sock} ->
        send_connect(sock, {version, vhost, login, passcode}, state)

      {:error, _} ->
        # Kernel.send self(), {:backoff, @backoff_interval}
        {:noreply, state}
    end
  end

  def handle_call(:disconnect, _from, %State{sock: sock} = state) do
    disconnect_id = "77"
    message = "DISCONNECT\nreceipt:#{disconnect_id}\n\n\0"

    case :gen_tcp.send(sock, message) do
      :ok ->
        {:reply, :ok, %State{state | disconnect_id: disconnect_id}}

      {:error, e} ->
        Logger.error(inspect(e))
        {:stop, :normal, :ok, state}
    end
  end

  def handle_call({:send, destination, body, opts}, _from, %State{sock: sock} = state) do
    message =
      "SEND\ndestination:#{destination}\ncontent-length:#{byte_size(body)}#{concat_opts(opts)}\n\n#{
        body
      }\0"

    case :gen_tcp.send(sock, message) do
      :ok ->
        send_callback(state.callback_handler, {:on_send, {"SEND", message}})
        {:reply, :ok, state}

      {:error, e} ->
        Logger.error(inspect(e))
        {:stop, :normal, :ok, state}
    end
  end

  def handle_call({:subscribe, destination, sub_id, opts}, _from, %State{sock: sock} = state) do
    message = "SUBSCRIBE\nid:#{sub_id}\ndestination:#{destination}#{concat_opts(opts)}\n\n\0"

    case :gen_tcp.send(sock, message) do
      :ok ->
        send_callback(state.callback_handler, {:on_send, {"SUBSCRIBE", message}})
        {:reply, :ok, state}

      {:error, e} ->
        Logger.error(inspect(e))
        {:stop, :normal, :ok, state}
    end
  end

  def handle_call({:unsubscribe, sub_id}, _from, %State{sock: sock} = state) do
    message = "UNSUBSCRIBE\nid:#{sub_id}\n\n\0"

    case :gen_tcp.send(sock, message) do
      :ok ->
        {:reply, :ok, state}

      {:error, e} ->
        Logger.error(inspect(e))
        {:stop, :normal, :ok, state}
    end
  end

  def handle_call({:ack, message_id}, _from, %State{sock: sock} = state) do
    message = "ACK\nid:#{message_id}\n\n\0"

    case :gen_tcp.send(sock, message) do
      :ok ->
        send_callback(state.callback_handler, {:on_send, {"ACK", message}})
        {:reply, :ok, state}

      {:error, e} ->
        Logger.error(inspect(e))
        {:stop, :normal, :ok, state}
    end
  end

  def handle_call({:ack, message_id, transaction_id}, _from, %State{sock: sock} = state) do
    message = "ACK\nid:#{message_id}\ntransaction:#{transaction_id}\n\n\0"

    case :gen_tcp.send(sock, message) do
      :ok ->
        {:reply, :ok, state}

      {:error, e} ->
        Logger.error(inspect(e))
        {:stop, :normal, :ok, state}
    end
  end

  def handle_call({:nack, message_id}, _from, %State{sock: sock} = state) do
    message = "NACK\nid:#{message_id}\n\n\0"

    case :gen_tcp.send(sock, message) do
      :ok ->
        send_callback(state.callback_handler, {:on_send, {"NACK", message}})
        {:reply, :ok, state}

      {:error, e} ->
        Logger.error(inspect(e))
        {:stop, :normal, :ok, state}
    end
  end

  def handle_call({:nack, message_id, transaction_id}, _from, %State{sock: sock} = state) do
    message = "NACK\nid:#{message_id}\ntransaction:#{transaction_id}\n\n\0"

    case :gen_tcp.send(sock, message) do
      :ok ->
        {:reply, :ok, state}

      {:error, e} ->
        Logger.error(inspect(e))
        {:stop, :normal, :ok, state}
    end
  end

  def handle_call({:begin_transaction, transaction_id}, _from, %State{sock: sock} = state) do
    message = "BEGIN\ntransaction:#{transaction_id}\n\n\0"

    case :gen_tcp.send(sock, message) do
      :ok ->
        {:reply, :ok, state}

      {:error, e} ->
        Logger.error(inspect(e))
        {:stop, :normal, :ok, state}
    end
  end

  def handle_call({:commit_transaction, transaction_id}, _from, %State{sock: sock} = state) do
    message = "COMMIT\ntransaction:#{transaction_id}\n\n\0"

    case :gen_tcp.send(sock, message) do
      :ok ->
        {:reply, :ok, state}

      {:error, e} ->
        Logger.error(inspect(e))
        {:stop, :normal, :ok, state}
    end
  end

  def handle_call({:abort_transaction, transaction_id}, _from, %State{sock: sock} = state) do
    message = "ABORT\ntransaction:#{transaction_id}\n\n\0"

    case :gen_tcp.send(sock, message) do
      :ok ->
        {:reply, :ok, state}

      {:error, e} ->
        Logger.error(inspect(e))
        {:stop, :normal, :ok, state}
    end
  end

  def handle_info(
        {:tcp, sock, message},
        %{logged_in: false, sock: sock, recv_buffer: buf} = state
      ) do
    # Allow the socket to send us the next message
    :inet.setopts(sock, active: :once)

    message2 = buf <> message
    {:ok, parsed} = Parser.parse_message(message2)
    %{type: type, headers: headers, body: body, remain: remain} = parsed

    state =
      case remain do
        "" -> %State{state | recv_buffer: ""}
        "\n" -> %State{state | recv_buffer: ""}
        _ -> %State{state | recv_buffer: remain}
      end

    case type do
      "CONNECTED" ->
        send_callback(state.callback_handler, {:on_connect, headers})
        {:noreply, %State{state | logged_in: true}}

      "ERROR" ->
        data = Map.merge(headers, %{"body" => body})
        send_callback(state.callback_handler, {:on_connect_error, data})
        {:stop, :normal, state}
    end
  end

  def handle_info({:tcp, sock, message}, %{logged_in: true, sock: sock, recv_buffer: buf} = state) do
    # Allow the socket to send us the next message
    :inet.setopts(sock, active: :once)

    message2 = buf <> message
    # Logger.debug inspect(message2, binaries: :as_strings)
    case loop_parse_message(message2, state) do
      :stop ->
        :gen_tcp.close(sock)
        {:stop, :normal, state}

      {:ok, remain} ->
        {:noreply, %State{state | recv_buffer: remain}}

      {:error, remain} ->
        Logger.error("parsing error in: #{inspect(message2, binaries: :as_strings)}")
        {:noreply, %State{state | recv_buffer: remain}}

      {:partial, remain} ->
        {:noreply, %State{state | recv_buffer: remain}}
    end
  end

  def handle_info({:tcp_closed, sock}, %{sock: sock} = state) do
    send_callback(state.callback_handler, {:on_disconnect, false})
    {:stop, :normal, state}
  end

  # Private functions
  defp concat_opts(opts) do
    opts
    |> Enum.filter(fn {_k, v} -> v != nil end)
    |> Enum.map(fn {k, v} -> "\n#{k}:#{v}" end)
    |> Enum.join()
  end

  defp send_connect(sock, {version, vhost, login, passcode}, state) do
    opts = %{login: login, passcode: passcode}
    message = "STOMP\naccept-version:#{version}\nhost:#{vhost}#{concat_opts(opts)}\n\n\0"

    case :gen_tcp.send(sock, message) do
      :ok ->
        {:reply, :ok, %State{state | sock: sock}}

      {:error, _} = e ->
        Logger.error(inspect(e))
        {:stop, :normal, :ok, state}
    end
  end

  defp send_callback(nil, _) do
    nil
  end

  defp send_callback(callback_handler, data) do
    data2 = Tuple.insert_at(data, 0, :stomp_client)
    Kernel.send(callback_handler, data2)
  end

  defp loop_parse_message("", _state) do
    {:ok, ""}
  end

  defp loop_parse_message("\n", _state) do
    {:ok, ""}
  end

  defp loop_parse_message(
         message,
         %State{callback_handler: callback_handler, disconnect_id: disconnect_id} = state
       ) do
    case Parser.parse_message(message) do
      {:ok, parsed} ->
        %{type: type, headers: headers, body: body, remain: remain} = parsed
        # Logger.debug inspect(parsed, binaries: :as_strings)

        if remain == message do
          {:ok, remain}
        else
          case type do
            "MESSAGE" ->
              data = Map.merge(headers, %{"body" => body})
              send_callback(callback_handler, {:on_message, data})
              loop_parse_message(remain, state)

            "RECEIPT" ->
              receipt_id = headers["receipt-id"]

              if receipt_id == disconnect_id do
                send_callback(callback_handler, {:on_disconnect, true})
                :stop
              else
                send_callback(callback_handler, {:on_receipt, receipt_id})
                loop_parse_message(remain, state)
              end

            "ERROR" ->
              data = Map.merge(headers, %{"body" => body})
              send_callback(callback_handler, {:on_message_error, data})
              Logger.error(inspect(data, binaries: :as_strings))
              loop_parse_message(remain, state)
          end
        end

      :partial ->
        {:partial, message}

      {:error, remain} ->
        {:error, remain}
    end
  end
end
