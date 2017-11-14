defmodule StompClient.ParserTest do
  use ExUnit.Case
  doctest StompClient.Parser

  alias StompClient.Parser

  test "parse partial message1" do
    message =
      "MESSAGE\nmessage-id:ID\test\c12408\c1\c1\c2\nbreadcrumbId:ID\test\c8\c8877250\c1\c1\ndestination:/topic/test\ntimestamp:1478021275091\nexpires:0\nsubscription:58\npersistent:true\npriority:4\nCamelJmsDeliveryMode:2\n\n<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n\0MESS"

    parsed = Parser.parse_message(message)
    {:ok, %{body: _, headers: _, remain: remain, type: type}} = parsed
    assert type == "MESSAGE"
    assert remain == "MESS"
  end

  test "parse partial message2" do
    message = "MESSAGE\noriginal-destination:/topic/test\nmessage-id:ID\test\c23\c1"
    parsed = Parser.parse_message(message)
    assert parsed == :partial
  end

  test "parse partial message3" do
    message = "MESSA"
    parsed = Parser.parse_message(message)
    assert parsed == :partial
  end
end
