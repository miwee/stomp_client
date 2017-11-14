defmodule StompClient.RabbitMQ.PersistedWorkQueue do
  import Kernel, except: [send: 2]

  @default_prefetch_count 1

  def subscribe(pid, topic) do
    subscribe(pid, topic, prefetch_count: @default_prefetch_count)
  end

  def subscribe(pid, topic, prefetch_count: prefetch_count) do
    topic2 = create_topic(topic)
    sub_id = :erlang.phash2(topic2)

    opts = [
      id: sub_id,
      durable: true,
      "auto-delete": false,
      "prefetch-count": prefetch_count,
      ack: "client-individual"
    ]

    StompClient.subscribe(pid, topic2, opts)
  end

  def send(pid, topic, payload, opts \\ []) do
    rabbit_opts = [persistent: true]
    Keyword.merge(opts, rabbit_opts, fn _k, _v1, v2 -> v2 end)
    StompClient.send(pid, create_topic(topic), payload, opts)
  end

  def ack(pid, %{"ack" => message_id} = _message) do
    StompClient.ack(pid, message_id)
  end

  def nack(pid, %{"ack" => message_id} = _message) do
    StompClient.ack(pid, message_id)
  end

  # Private functions
  defp create_topic(<<?/, topic::binary>>) do
    "/queue/" <> topic
  end

  defp create_topic(topic) do
    "/queue/" <> topic
  end
end
