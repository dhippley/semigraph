defmodule Semigraph.Query.Parser do
  @moduledoc """
  Parses Cypher-like query strings into AST structures.

  Supports basic MATCH, WHERE, and RETURN clauses with simple patterns.
  """

  alias Semigraph.Query.AST

  @doc """
  Parses a query string into an AST.

  ## Examples

      iex> parse("MATCH (n:Person) RETURN n")
      {:ok, %AST{...}}

      iex> parse("MATCH (a)-[r:KNOWS]->(b) WHERE a.age > 25 RETURN a.name, b.name")
      {:ok, %AST{...}}
  """
  @spec parse(String.t()) :: {:ok, AST.t()} | {:error, term()}
  def parse(query_string) when is_binary(query_string) do
    try do
      tokens = tokenize(query_string)
      ast = parse_tokens(tokens)
      {:ok, ast}
    rescue
      error -> {:error, error}
    catch
      :throw, error -> {:error, error}
    end
  end

  # Tokenization

  defp tokenize(query_string) do
    query_string
    |> String.trim()
    |> String.split(~r/\s+/)
    |> Enum.reject(&(&1 == ""))
    |> convert_to_tokens()
  end

  defp convert_to_tokens(words) do
    words
    |> Enum.flat_map(&split_special_chars/1)
    |> Enum.map(&normalize_token/1)
  end

  defp split_special_chars(word) do
    # Split on special characters while preserving them
    word
    |> String.replace(~r/([(),\[\]\-><:\.])/, " \\1 ")
    |> String.split()
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_token(token) do
    case String.upcase(token) do
      "MATCH" -> {:keyword, :match}
      "WHERE" -> {:keyword, :where}
      "RETURN" -> {:keyword, :return}
      "ORDER" -> {:keyword, :order}
      "BY" -> {:keyword, :by}
      "LIMIT" -> {:keyword, :limit}
      "SKIP" -> {:keyword, :skip}
      "AND" -> {:operator, :and}
      "OR" -> {:operator, :or}
      "NOT" -> {:operator, :not}
      "AS" -> {:keyword, :as}
      "(" -> {:paren, :open}
      ")" -> {:paren, :close}
      "[" -> {:bracket, :open}
      "]" -> {:bracket, :close}
      "-" -> {:dash, :dash}
      ">" -> {:arrow, :right}
      "<" -> {:arrow, :left}
      ":" -> {:colon, :colon}
      "." -> {:dot, :dot}
      "," -> {:comma, :comma}
      "=" -> {:comparison, :eq}
      "!=" -> {:comparison, :neq}
      "<>" -> {:comparison, :neq}
      ">=" -> {:comparison, :gte}
      "<=" -> {:comparison, :lte}
      _ ->
        cond do
          String.match?(token, ~r/^\d+$/) -> {:number, String.to_integer(token)}
          String.match?(token, ~r/^\d*\.\d+$/) -> {:number, String.to_float(token)}
          String.starts_with?(token, "'") && String.ends_with?(token, "'") ->
            {:string, String.slice(token, 1..-2//1)}
          String.starts_with?(token, "\"") && String.ends_with?(token, "\"") ->
            {:string, String.slice(token, 1..-2//1)}
          true -> {:identifier, token}
        end
    end
  end

  # Parsing

  defp parse_tokens(tokens) do
    state = %{
      tokens: tokens,
      position: 0,
      ast: AST.new()
    }

    parse_query(state)
  end

  defp parse_query(state) do
    state
    |> parse_match_clauses()
    |> parse_where_clause()
    |> parse_return_clause()
    |> parse_order_clause()
    |> parse_limit_clause()
    |> parse_skip_clause()
    |> Map.get(:ast)
  end

  defp parse_match_clauses(%{ast: ast} = state) do
    case peek_token(state) do
      {:keyword, :match} ->
        {pattern, new_state} = parse_match_clause(advance(state))
        updated_ast = AST.add_match_pattern(ast, pattern)
        parse_match_clauses(%{new_state | ast: updated_ast})
      _ -> state
    end
  end

  defp parse_match_clause(state) do
    parse_path_pattern(state)
  end

  defp parse_path_pattern(state) do
    {nodes, edges, new_state} = parse_pattern_elements(state, [], [])

    pattern = %{
      nodes: nodes,
      edges: edges
    }

    {pattern, new_state}
  end

  defp parse_pattern_elements(state, nodes, edges) do
    case peek_token(state) do
      {:paren, :open} ->
        {node, new_state} = parse_node_pattern(state)
        parse_pattern_elements(new_state, nodes ++ [node], edges)

      {:dash, :dash} ->
        {edge, new_state} = parse_edge_pattern(state)
        parse_pattern_elements(new_state, nodes, edges ++ [edge])

      _ -> {nodes, edges, state}
    end
  end

  defp parse_node_pattern(state) do
    state = expect_token(state, {:paren, :open})

    {variable, state} = case peek_token(state) do
      {:identifier, var} -> {var, advance(state)}
      _ -> {nil, state}
    end

    {labels, state} = parse_labels(state, [])
    {properties, state} = parse_properties(state)

    state = expect_token(state, {:paren, :close})

    node_pattern = %{
      variable: variable,
      labels: labels,
      properties: properties
    }

    {node_pattern, state}
  end

  defp parse_labels(state, labels) do
    case peek_token(state) do
      {:colon, :colon} ->
        state = advance(state)
        case peek_token(state) do
          {:identifier, label} ->
            parse_labels(advance(state), labels ++ [label])
          _ -> throw("Expected label after :")
        end
      _ -> {labels, state}
    end
  end

  defp parse_properties(state) do
    # Simple property parsing - just return empty for now
    # TODO: Implement proper property parsing with {}
    {%{}, state}
  end

  defp parse_edge_pattern(state) do
    state = expect_token(state, {:dash, :dash})

    # Check for direction and brackets
    {direction, state} = case peek_token(state) do
      {:arrow, :left} ->
        state = advance(state)
        state = expect_token(state, {:bracket, :open})
        {:incoming, state}
      {:bracket, :open} ->
        {:undirected, state}
      _ -> {:outgoing, state}
    end

    # Parse bracket content if present
    {variable, relationship_type, properties, state} =
      if direction != :outgoing do
        parse_edge_details(state)
      else
        {nil, nil, %{}, state}
      end

    # Handle outgoing direction
    {direction, state} = case {direction, peek_token(state)} do
      {:undirected, {:bracket, :close}} ->
        state = advance(state)
        case peek_token(state) do
          {:arrow, :right} -> {:outgoing, advance(state)}
          _ -> {:undirected, state}
        end
      {:undirected, _} -> {:outgoing, state}
      {dir, _} -> {dir, state}
    end

    edge_pattern = %{
      variable: variable,
      relationship_type: relationship_type,
      properties: properties,
      direction: direction
    }

    {edge_pattern, state}
  end

  defp parse_edge_details(state) do
    {variable, state} = case peek_token(state) do
      {:identifier, var} -> {var, advance(state)}
      _ -> {nil, state}
    end

    {relationship_type, state} = case peek_token(state) do
      {:colon, :colon} ->
        state = advance(state)
        case peek_token(state) do
          {:identifier, type} -> {type, advance(state)}
          _ -> {nil, state}
        end
      _ -> {nil, state}
    end

    {properties, state} = parse_properties(state)

    state = expect_token(state, {:bracket, :close})

    {variable, relationship_type, properties, state}
  end

  defp parse_where_clause(state) do
    case peek_token(state) do
      {:keyword, :where} ->
        state = advance(state)
        {condition, new_state} = parse_condition(state)
        updated_ast = AST.add_where_condition(state.ast, condition)
        %{new_state | ast: updated_ast}
      _ -> state
    end
  end

  defp parse_condition(state) do
    parse_or_condition(state)
  end

  defp parse_or_condition(state) do
    {left, state} = parse_and_condition(state)

    case peek_token(state) do
      {:operator, :or} ->
        state = advance(state)
        {right, state} = parse_or_condition(state)
        condition = %{type: :logical, op: :or, conditions: [left, right]}
        {condition, state}
      _ -> {left, state}
    end
  end

  defp parse_and_condition(state) do
    {left, state} = parse_primary_condition(state)

    case peek_token(state) do
      {:operator, :and} ->
        state = advance(state)
        {right, state} = parse_and_condition(state)
        condition = %{type: :logical, op: :and, conditions: [left, right]}
        {condition, state}
      _ -> {left, state}
    end
  end

  defp parse_primary_condition(state) do
    case peek_token(state) do
      {:operator, :not} ->
        state = advance(state)
        {condition, state} = parse_primary_condition(state)
        not_condition = %{type: :logical, op: :not, conditions: [condition]}
        {not_condition, state}

      {:paren, :open} ->
        state = advance(state)
        {condition, state} = parse_condition(state)
        state = expect_token(state, {:paren, :close})
        {condition, state}

      _ -> parse_comparison_condition(state)
    end
  end

  defp parse_comparison_condition(state) do
    {left, state} = parse_value_expression(state)

    case peek_token(state) do
      {:comparison, op} ->
        state = advance(state)
        {right, state} = parse_value_expression(state)
        condition = %{type: :comparison, left: left, op: op, right: right}
        {condition, state}
      _ -> throw("Expected comparison operator")
    end
  end

  defp parse_value_expression(state) do
    case peek_token(state) do
      {:identifier, var} ->
        state = advance(state)
        case peek_token(state) do
          {:dot, :dot} ->
            state = advance(state)
            case peek_token(state) do
              {:identifier, prop} ->
                state = advance(state)
                value = %{variable: var, property: prop}
                {value, state}
              _ -> throw("Expected property name after .")
            end
          _ ->
            value = %{variable: var}
            {value, state}
        end
      {:string, str} -> {str, advance(state)}
      {:number, num} -> {num, advance(state)}
      _ -> throw("Expected value expression")
    end
  end

  defp parse_return_clause(state) do
    case peek_token(state) do
      {:keyword, :return} ->
        state = advance(state)
        {return_items, new_state} = parse_return_items(state, [])
        updated_ast = AST.set_return_items(state.ast, return_items)
        %{new_state | ast: updated_ast}
      _ -> state
    end
  end

  defp parse_return_items(state, items) do
    {item, state} = parse_return_item(state)
    items = items ++ [item]

    case peek_token(state) do
      {:comma, :comma} ->
        state = advance(state)
        parse_return_items(state, items)
      _ -> {items, state}
    end
  end

  defp parse_return_item(state) do
    case peek_token(state) do
      {:identifier, var} ->
        state = advance(state)
        case peek_token(state) do
          {:dot, :dot} ->
            state = advance(state)
            case peek_token(state) do
              {:identifier, prop} ->
                state = advance(state)
                item = %{type: :property, variable: var, property: prop}
                {item, state}
              _ -> throw("Expected property name after .")
            end
          _ ->
            item = %{type: :variable, variable: var}
            {item, state}
        end
      _ -> throw("Expected return item")
    end
  end

  defp parse_order_clause(state), do: state # TODO: Implement
  defp parse_limit_clause(state), do: state # TODO: Implement
  defp parse_skip_clause(state), do: state # TODO: Implement

  # Utility functions

  defp peek_token(%{tokens: tokens, position: pos}) do
    Enum.at(tokens, pos)
  end

  defp advance(%{position: pos} = state) do
    %{state | position: pos + 1}
  end

  defp expect_token(state, expected_token) do
    case peek_token(state) do
      ^expected_token -> advance(state)
      actual -> throw("Expected #{inspect(expected_token)}, got #{inspect(actual)}")
    end
  end
end
