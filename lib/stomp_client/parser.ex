defmodule StompClient.Parser do
  require Logger

  def parse_message(message) do
    [type, {headers, message_body}, remain] = get_type(message)
    [{:type, type}, {:headers, headers}, {:body, message_body}, remain]
  end

  defp get_message_body(message) do
    get_message_body(message, "")
  end
  defp get_message_body(<<x, r::binary>>, message_body) do
    case(x) do
      0 ->
        {message_body, r}

      _ ->
        {my_message_body, remain} = get_message_body(r, message_body)
        {message_body <> <<x>> <> my_message_body, remain}
    end
  end
  defp get_message_body("", "") do
    {"", ""}
  end

  defp get_message_body_with_length(r, length_str) when is_binary(length_str) do
    case Integer.parse(length_str) do 
      {n, ""} -> get_message_body_with_length(r, n) 
      _       -> {"", r}
    end
  end
  defp get_message_body_with_length(r, n) when is_integer(n) and n <= byte_size(r) do
    <<body::binary-size(n), x, r2::binary>> = r
    case x do 
      0 -> {body, r2}
      _ -> {"", r}
    end
  end
  defp get_message_body_with_length(r, _n) do
    {"", r}
  end

  defp get_headers(message) do
    get_headers(message, "")
  end
  defp get_headers(message, headers) do
    get_headers(message, headers, -1)
  end
  defp get_headers(<<x, r::binary>>, headers, last_char) do
    case({x, last_char}) do
      {?\n, ?\n} ->
        {parsed_headers, _} = get_headers_from_raw_src([], headers)
        parsed_headers = Enum.into(parsed_headers, %{})
        {message_body, remain} =
          case Map.get(parsed_headers, "content-length", nil) do 
            nil -> 
              get_message_body(r)

            length_str ->
              get_message_body_with_length(r, length_str)
          end

        [{parsed_headers, message_body}, remain]

      {_, _} ->
        get_headers(r, headers <> <<x>>, x)
    end
  end

  defp get_type(message) do
    get_type(message, "")
  end
  defp get_type("", type) do
    type
  end
  defp get_type(<<x, r::binary>>, "") do
    case(x) do
      ?\n -> # ignore leading \n
        get_type(r, "")

      _ ->
        get_type(r, <<x>>)
    end
  end
  defp get_type(<<x, r::binary>>, type) do
    case(x) do
      ?\n ->
        [{headers, message_body}, remain] = get_headers(r)
        [type, {headers, message_body}, remain]

      _ ->
        get_type(r, type <> <<x>>)
    end
  end

  defp get_headers_from_raw_src(headers, "") do
    {headers, ""}
  end
  defp get_headers_from_raw_src(headers, raw_src) do
    {header, remaining_message} = get_header(raw_src)
    get_headers_from_raw_src(headers ++ [header], remaining_message)
  end

  defp get_header(raw_src) do
    {header_name, remaining_message_after_header_extraction} = get_header_name("", raw_src)
    {header_value, remaining_message_after_value_extraction} = get_header_value("", remaining_message_after_header_extraction)
    {{header_name, header_value}, remaining_message_after_value_extraction}
  end

  defp get_header_name(header_name, <<x, r::binary>>) do
    case x do
      ?: ->
        {header_name, r}

      _ ->
        get_header_name(header_name <> <<x>>, r)
    end
  end

  defp get_header_value(header_value, <<x, r::binary>>) do
    case x do
      ?\n ->
        {header_value, r}

      _ ->
        get_header_value(header_value <> <<x>>, r)
    end
  end
end
