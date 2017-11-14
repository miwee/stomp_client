defmodule StompClient.Parser do
  require Logger

  def parse_message(message) do
    case get_type(message) do
      :partial ->
        :partial

      {:error, remain} ->
        {:error, remain}

      {type, {headers, message_body}, remain} ->
        {:ok, %{type: type, headers: headers, body: message_body, remain: remain}}

      _remain ->
        :partial
    end
  end

  defp get_message_body(message) do
    get_message_body(message, "")
  end

  defp get_message_body(<<x, r::binary>>, message_body) do
    case x do
      0 ->
        {message_body, r}

      _ ->
        case get_message_body(r, message_body) do
          :partial ->
            :partial

          {my_message_body, remain} ->
            {message_body <> <<x>> <> my_message_body, remain}
        end
    end
  end

  defp get_message_body("", "") do
    :partial
  end

  defp get_message_body_with_length(r, length_str) when is_binary(length_str) do
    case Integer.parse(length_str) do
      {n, ""} -> get_message_body_with_length(r, n)
      _ -> {:error, r}
    end
  end

  defp get_message_body_with_length(r, n) when is_integer(n) and n <= byte_size(r) do
    <<body::binary-size(n), x, r2::binary>> = r

    case x do
      0 -> {body, r2}
      _ -> {:error, r}
    end
  end

  defp get_message_body_with_length(_r, _n) do
    :partial
  end

  defp get_headers(message) do
    get_headers(message, "")
  end

  defp get_headers(message, headers) do
    get_headers(message, headers, -1)
  end

  defp get_headers("", _, _) do
    :partial
  end

  defp get_headers(<<x, r::binary>>, headers, last_char) do
    case {x, last_char} do
      {?\n, ?\n} ->
        {parsed_headers, _} = get_headers_from_raw_src([], headers)
        parsed_headers = Enum.into(parsed_headers, %{})

        case Map.get(parsed_headers, "content-length") do
          nil ->
            case get_message_body(r) do
              :partial ->
                :partial

              {message_body, remain} ->
                {{parsed_headers, message_body}, remain}
            end

          length_str ->
            case get_message_body_with_length(r, length_str) do
              :partial ->
                :partial

              {:error, remain} ->
                {:error, remain}

              {message_body, remain} ->
                {{parsed_headers, message_body}, remain}
            end
        end

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
    case x do
      # ignore leading \n
      ?\n ->
        get_type(r, "")

      _ ->
        get_type(r, <<x>>)
    end
  end

  defp get_type(<<x, r::binary>>, type) do
    case x do
      ?\n ->
        case get_headers(r) do
          :partial ->
            :partial

          {:error, remain} ->
            {:error, remain}

          {{headers, message_body}, remain} ->
            {type, {headers, message_body}, remain}
        end

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

    {header_value, remaining_message_after_value_extraction} =
      get_header_value("", remaining_message_after_header_extraction)

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
