defmodule Semigraph.Query.Executor do
  @moduledoc """
  Executes query ASTs against graph storage.

  Provides optimized execution plans and result collection.
  """

  alias Semigraph.{Graph, Node, Edge}
  alias Semigraph.Query.{AST, Pattern}

  @type binding :: %{String.t() => Node.t() | Edge.t()}
  @type result_row :: %{String.t() => term()}
  @type execution_result :: %{
    rows: [result_row()],
    columns: [String.t()],
    stats: %{
      nodes_visited: non_neg_integer(),
      edges_traversed: non_neg_integer(),
      execution_time_ms: float()
    }
  }

  @doc """
  Executes a query AST against a graph.
  """
  @spec execute(AST.t(), Graph.t()) :: {:ok, execution_result()} | {:error, term()}
  def execute(%AST{} = query, %Graph{} = graph) do
    start_time = System.monotonic_time(:millisecond)

    try do
      # Execute the query pipeline
      result = query
      |> find_starting_bindings(graph)
      |> apply_match_patterns(query, graph)
      |> apply_where_conditions(query)
      |> build_return_results(query)
      |> apply_ordering_and_limits(query)

      end_time = System.monotonic_time(:millisecond)
      execution_time = end_time - start_time

      columns = extract_column_names(query.return_items)

      final_result = %{
        rows: result,
        columns: columns,
        stats: %{
          nodes_visited: 0, # TODO: Track these metrics
          edges_traversed: 0,
          execution_time_ms: execution_time
        }
      }

      {:ok, final_result}
    rescue
      error -> {:error, error}
    end
  end

  # Private execution pipeline functions

  defp find_starting_bindings(%AST{match_patterns: []}, _graph) do
    [%{}] # Empty binding for queries without MATCH
  end

  defp find_starting_bindings(%AST{match_patterns: [first_pattern | _]}, graph) do
    # Start with the first node in the first pattern
    first_node_pattern = hd(first_pattern.nodes)

    # Find all nodes that match the first pattern
    matching_nodes = Graph.list_nodes(graph)
    |> Enum.filter(&Pattern.matches_node?(&1, first_node_pattern))

    # Create initial bindings
    case first_node_pattern.variable do
      nil -> [%{}] # No variable binding needed
      var -> Enum.map(matching_nodes, &(%{var => &1}))
    end
  end

  defp apply_match_patterns(bindings, %AST{match_patterns: patterns}, graph) do
    Enum.reduce(patterns, bindings, fn pattern, acc_bindings ->
      Enum.flat_map(acc_bindings, &expand_binding_with_pattern(&1, pattern, graph))
    end)
  end

  defp expand_binding_with_pattern(binding, pattern, graph) do
    case {pattern.nodes, pattern.edges} do
      {[_single_node], []} ->
        # Single node pattern - already handled in starting bindings
        [binding]

      {[from_node, to_node], [edge_pattern]} ->
        # Simple two-node, one-edge pattern
        expand_simple_edge_pattern(binding, from_node, edge_pattern, to_node, graph)

      _ ->
        # Complex multi-hop patterns - TODO: implement
        [binding]
    end
  end

  defp expand_simple_edge_pattern(binding, from_pattern, edge_pattern, to_pattern, graph) do
    from_var = from_pattern.variable
    to_var = to_pattern.variable
    edge_var = edge_pattern.variable

    # Get the bound from_node or find matching nodes
    from_nodes = case from_var && Map.get(binding, from_var) do
      %Node{} = node -> [node]
      nil ->
        Graph.list_nodes(graph)
        |> Enum.filter(&Pattern.matches_node?(&1, from_pattern))
    end

    # For each from_node, find matching edges and to_nodes
    Enum.flat_map(from_nodes, fn from_node ->
      edges = case edge_pattern.direction do
        :outgoing -> Graph.get_outgoing_edges(graph, from_node.id)
        :incoming -> Graph.get_incoming_edges(graph, from_node.id)
        :undirected ->
          Graph.get_outgoing_edges(graph, from_node.id) ++
          Graph.get_incoming_edges(graph, from_node.id)
      end

      # Filter edges by pattern
      matching_edges = Enum.filter(edges, &Pattern.matches_edge?(&1, edge_pattern))

      # For each matching edge, get the to_node
      Enum.flat_map(matching_edges, fn edge ->
        to_node_id = case edge_pattern.direction do
          :outgoing -> edge.to_node_id
          :incoming -> edge.from_node_id
          :undirected ->
            if edge.from_node_id == from_node.id do
              edge.to_node_id
            else
              edge.from_node_id
            end
        end

        case Graph.get_node(graph, to_node_id) do
          {:ok, to_node} ->
            if Pattern.matches_node?(to_node, to_pattern) do
              new_binding = binding
              |> maybe_add_binding(from_var, from_node)
              |> maybe_add_binding(to_var, to_node)
              |> maybe_add_binding(edge_var, edge)

              [new_binding]
            else
              []
            end
          _ -> []
        end
      end)
    end)
  end

  defp maybe_add_binding(binding, nil, _value), do: binding
  defp maybe_add_binding(binding, var, value), do: Map.put(binding, var, value)

  defp apply_where_conditions(bindings, %AST{where_conditions: []}), do: bindings
  defp apply_where_conditions(bindings, %AST{where_conditions: conditions}) do
    Enum.filter(bindings, fn binding ->
      Enum.all?(conditions, &evaluate_condition(&1, binding))
    end)
  end

  defp evaluate_condition(%{type: :comparison, left: left, op: op, right: right}, binding) do
    left_val = resolve_value(left, binding)
    right_val = resolve_value(right, binding)

    case op do
      :eq -> left_val == right_val
      :neq -> left_val != right_val
      :gt -> left_val > right_val
      :gte -> left_val >= right_val
      :lt -> left_val < right_val
      :lte -> left_val <= right_val
      :in -> right_val |> Enum.member?(left_val)
      :contains -> left_val |> String.contains?(right_val)
    end
  end

  defp evaluate_condition(%{type: :logical, op: :and, conditions: conditions}, binding) do
    Enum.all?(conditions, &evaluate_condition(&1, binding))
  end

  defp evaluate_condition(%{type: :logical, op: :or, conditions: conditions}, binding) do
    Enum.any?(conditions, &evaluate_condition(&1, binding))
  end

  defp evaluate_condition(%{type: :logical, op: :not, conditions: [condition]}, binding) do
    not evaluate_condition(condition, binding)
  end

  defp evaluate_condition(%{type: :property_exists, variable: var, property: prop}, binding) do
    case Map.get(binding, var) do
      %Node{properties: props} -> Map.has_key?(props, prop)
      %Edge{properties: props} -> Map.has_key?(props, prop)
      _ -> false
    end
  end

  defp resolve_value(%{variable: var, property: prop}, binding) when is_binary(var) do
    case Map.get(binding, var) do
      %Node{properties: props} -> Map.get(props, prop)
      %Edge{properties: props} -> Map.get(props, prop)
      _ -> nil
    end
  end

  defp resolve_value(%{variable: var}, binding) when is_binary(var) do
    Map.get(binding, var)
  end

  defp resolve_value(literal_value, _binding), do: literal_value

  defp build_return_results(bindings, %AST{return_items: return_items}) do
    Enum.map(bindings, fn binding ->
      Enum.into(return_items, %{}, fn item ->
        {item_key(item), resolve_return_item(item, binding)}
      end)
    end)
  end

  defp resolve_return_item(%{type: :variable, variable: var}, binding) do
    Map.get(binding, var)
  end

  defp resolve_return_item(%{type: :property, variable: var, property: prop}, binding) do
    case Map.get(binding, var) do
      %Node{properties: props} -> Map.get(props, prop)
      %Edge{properties: props} -> Map.get(props, prop)
      _ -> nil
    end
  end

  defp resolve_return_item(%{type: :aggregation, function: _func, variable: var, property: prop}, binding) do
    # TODO: Implement aggregations properly
    # For now, just return the value
    case prop do
      nil -> Map.get(binding, var)
      _ -> resolve_return_item(%{type: :property, variable: var, property: prop}, binding)
    end
  end

  defp item_key(%{type: :variable, variable: var}), do: var
  defp item_key(%{type: :property, variable: var, property: prop}), do: "#{var}.#{prop}"
  defp item_key(%{type: :aggregation, function: func, variable: var, property: nil}), do: "#{func}(#{var})"
  defp item_key(%{type: :aggregation, function: func, variable: var, property: prop}), do: "#{func}(#{var}.#{prop})"

  defp apply_ordering_and_limits(results, %AST{order_by: order_by, limit: limit, skip: skip}) do
    results
    |> apply_ordering(order_by)
    |> apply_skip(skip)
    |> apply_limit(limit)
  end

  defp apply_ordering(results, []), do: results
  defp apply_ordering(results, order_by) do
    Enum.sort(results, fn row1, row2 ->
      Enum.reduce_while(order_by, :eq, fn {var, direction}, acc ->
        case acc do
          :eq ->
            val1 = Map.get(row1, var)
            val2 = Map.get(row2, var)
            case {direction, compare_values(val1, val2)} do
              {:asc, :lt} -> {:halt, true}
              {:asc, :gt} -> {:halt, false}
              {:desc, :lt} -> {:halt, false}
              {:desc, :gt} -> {:halt, true}
              {_, :eq} -> {:cont, :eq}
            end
          result -> {:halt, result}
        end
      end)
    end)
  end

  defp compare_values(val1, val2) when val1 < val2, do: :lt
  defp compare_values(val1, val2) when val1 > val2, do: :gt
  defp compare_values(_, _), do: :eq

  defp apply_skip(results, nil), do: results
  defp apply_skip(results, skip), do: Enum.drop(results, skip)

  defp apply_limit(results, nil), do: results
  defp apply_limit(results, limit), do: Enum.take(results, limit)

  defp extract_column_names(return_items) do
    Enum.map(return_items, &item_key/1)
  end
end
