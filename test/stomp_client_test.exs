defmodule StompClientTest do
  use ExUnit.Case
  doctest StompClient

  defp connect do
    StompClient.connect(StompClientTest.Config.connect_opts(), callback_handler: self())
  end

  defp disconnect(pid) do
    StompClient.stop(pid)
  end

  test "stomp_on_connect callback on sending connect" do
    pid = connect()
    assert_receive {:stomp_client, :on_connect, _}
    disconnect(pid)
  end

  test "stomp_on_message callback on sending message" do
    pid = connect()
    assert_receive {:stomp_client, :on_connect, _}
    StompClient.subscribe(pid, "test1", id: 1)
    StompClient.send(pid, "test1", "test data")
    assert_receive {:stomp_client, :on_message, %{"body" => "test data"}}
    disconnect(pid)
  end

  test "stomp_on_subscribe_error callback on subscribing again for same {topic, id} pair" do
    pid = connect()
    assert_receive {:stomp_client, :on_connect, _}
    StompClient.subscribe(pid, "test1", id: 1, receipt: 12)
    assert_receive {:stomp_client, :on_receipt, "12"}
    StompClient.subscribe(pid, "test1", id: 1)
    assert_receive {:stomp_client, :on_message_error, %{"message" => "Duplicated subscription identifier"}}
    assert_receive {:stomp_client, :on_disconnect, _}
  end
end
