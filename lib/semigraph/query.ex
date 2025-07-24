defmodule Semigraph.Query do
  @moduledoc """
  Main query interface for Semigraph.

  Provides both a Cypher-like string query interface and an Elixir DSL
  for building and executing graph queries.

  ## Examples

  ### String Queries (Cypher-like)

      iex> query = "MATCH (n:Person) WHERE n.age > 25 RETURN n.name"
      iex> Semigraph.Query.execute(graph, query)
      {:ok, %{rows: [%{"n.name" => "Alice"}, %{"n.name" => "Bob"}], ...}}

  ### DSL Queries

      iex> import Semigraph.Query
      iex> result = graph
      ...> |> match([{:n, :Person}])
      ...> |> where(n.age > 25)
      ...> |> return([:n.name])
      ...> |> execute()
      {:ok, %{rows: [...], ...}}
  """

  alias Semigraph.{Graph, Storage, Node}
  alias Semigraph.Query.{AST, Parser, Executor}

  # QueryBuilder struct for DSL

  defmodule QueryBuilder do
    @moduledoc false

    defstruct [:graph, :ast]

    @type t :: %__MODULE__{
      graph: Graph.t(),
      ast: AST.t()
    }
  end

  @doc """
  Executes a query against a graph.

  Accepts either a query string or an AST structure.
  """
  @spec execute(Graph.t(), String.t() | AST.t()) :: {:ok, Executor.execution_result()} | {:error, term()}
  def execute(%Graph{} = graph, query_string) when is_binary(query_string) do
    with {:ok, ast} <- Parser.parse(query_string) do
      Executor.execute(ast, graph)
    end
  end

  def execute(%Graph{} = graph, %AST{} = ast) do
    Executor.execute(ast, graph)
  end

  @doc """
  Convenience function to parse and execute a query string.
  """
  @spec run(Graph.t(), String.t()) :: {:ok, Executor.execution_result()} | {:error, term()}
  def run(%Graph{} = graph, query_string) when is_binary(query_string) do
    execute(graph, query_string)
  end

  @doc """
  Starts building a query with a MATCH clause.

  ## Examples

      iex> match(graph, [{:n, :Person}])
      %QueryBuilder{...}

      iex> match(graph, [{:a, :Person}, {:r, :KNOWS}, {:b, :Person}])
      %QueryBuilder{...}
  """
  def match(%Graph{} = graph, patterns) when is_list(patterns) do
    %QueryBuilder{
      graph: graph,
      ast: AST.new() |> add_patterns_to_ast(patterns)
    }
  end

  @doc """
  Adds WHERE conditions to a query.
  """
  def where(%QueryBuilder{ast: ast} = builder, condition) do
    # TODO: Convert Elixir expressions to AST conditions
    # For now, accept simple conditions
    %{builder | ast: AST.add_where_condition(ast, condition)}
  end

  @doc """
  Adds RETURN items to a query.
  """
  def return(%QueryBuilder{ast: ast} = builder, items) when is_list(items) do
    return_items = Enum.map(items, &convert_to_return_item/1)
    %{builder | ast: AST.set_return_items(ast, return_items)}
  end

  @doc """
  Sets LIMIT on a query.
  """
  def limit(%QueryBuilder{ast: ast} = builder, count) when is_integer(count) and count > 0 do
    %{builder | ast: AST.set_limit(ast, count)}
  end

  @doc """
  Sets SKIP on a query.
  """
  def skip(%QueryBuilder{ast: ast} = builder, count) when is_integer(count) and count >= 0 do
    %{builder | ast: AST.set_skip(ast, count)}
  end

  @doc """
  Adds ORDER BY to a query.
  """
  def order_by(%QueryBuilder{ast: ast} = builder, variable, direction \\ :asc)
      when direction in [:asc, :desc] do
    %{builder | ast: AST.add_order_by(ast, to_string(variable), direction)}
  end

  @doc """
  Executes a built query.
  """
  def execute(%QueryBuilder{graph: graph, ast: ast}) do
    Executor.execute(ast, graph)
  end

  # Private helper functions

  defp add_patterns_to_ast(ast, patterns) do
    # Convert simple patterns to proper AST patterns
    # For now, handle basic node patterns
    path_patterns = convert_patterns_to_ast(patterns)
    Enum.reduce(path_patterns, ast, &AST.add_match_pattern(&2, &1))
  end

  defp convert_patterns_to_ast(patterns) do
    # Group patterns into paths (nodes and edges)
    [convert_simple_pattern(patterns)]
  end

  defp convert_simple_pattern(patterns) do
    {nodes, edges} = parse_pattern_elements(patterns, [], [])
    %{nodes: nodes, edges: edges}
  end

  defp parse_pattern_elements([], nodes, edges), do: {Enum.reverse(nodes), Enum.reverse(edges)}

  defp parse_pattern_elements([{var, label} | rest], nodes, edges) when is_atom(var) and is_atom(label) do
    node_pattern = %{
      variable: to_string(var),
      labels: [to_string(label)],
      properties: %{}
    }
    parse_pattern_elements(rest, [node_pattern | nodes], edges)
  end

  defp parse_pattern_elements([{var, label, props} | rest], nodes, edges)
      when is_atom(var) and is_atom(label) and is_map(props) do
    node_pattern = %{
      variable: to_string(var),
      labels: [to_string(label)],
      properties: props
    }
    parse_pattern_elements(rest, [node_pattern | nodes], edges)
  end

  defp parse_pattern_elements([{:-, rel_type} | rest], nodes, edges) when is_atom(rel_type) do
    edge_pattern = %{
      variable: nil,
      relationship_type: to_string(rel_type),
      properties: %{},
      direction: :outgoing
    }
    parse_pattern_elements(rest, nodes, [edge_pattern | edges])
  end

  defp parse_pattern_elements([{:-, var, rel_type} | rest], nodes, edges)
      when is_atom(var) and is_atom(rel_type) do
    edge_pattern = %{
      variable: to_string(var),
      relationship_type: to_string(rel_type),
      properties: %{},
      direction: :outgoing
    }
    parse_pattern_elements(rest, nodes, [edge_pattern | edges])
  end

  defp parse_pattern_elements([pattern | _rest], _nodes, _edges) do
    raise ArgumentError, "Unsupported pattern format: #{inspect(pattern)}"
  end

  defp convert_to_return_item(item) when is_atom(item) do
    %{type: :variable, variable: to_string(item)}
  end

  defp convert_to_return_item({var, prop}) when is_atom(var) and is_atom(prop) do
    %{type: :property, variable: to_string(var), property: to_string(prop)}
  end

  defp convert_to_return_item({{func, var}}) when is_atom(func) and is_atom(var) do
    %{type: :aggregation, function: func, variable: to_string(var), property: nil}
  end

  defp convert_to_return_item({{func, var, prop}}) when is_atom(func) and is_atom(var) and is_atom(prop) do
    %{type: :aggregation, function: func, variable: to_string(var), property: to_string(prop)}
  end

  defp convert_to_return_item(item) do
    raise ArgumentError, "Unsupported return item format: #{inspect(item)}"
  end

  # Legacy functions for backward compatibility

  @doc """
  Simple path traversal without full query parsing.
  """
  @spec traverse(Graph.t(), Node.id(), keyword()) :: [Node.t()]
  def traverse(%Graph{storage: storage} = _graph, start_node_id, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 3)
    direction = Keyword.get(opts, :direction, :both)  # :in, :out, :both

    traverse_recursive(storage, [start_node_id], MapSet.new([start_node_id]), 0, max_depth, direction)
    |> Enum.map(fn node_id ->
      case Storage.get_node(storage, node_id) do
        {:ok, node} -> node
        {:error, _} -> nil
      end
    end)
    |> Enum.filter(& &1)
  end

  defp traverse_recursive(_storage, [], _visited, _depth, _max_depth, _direction) do
    []
  end

  defp traverse_recursive(_storage, _current_nodes, visited, depth, max_depth, _direction) when depth >= max_depth do
    MapSet.to_list(visited)
  end

  defp traverse_recursive(storage, current_nodes, visited, depth, max_depth, direction) do
    next_nodes =
      current_nodes
      |> Enum.flat_map(fn node_id ->
        Storage.get_edges_for_node(storage, node_id)
        |> Enum.flat_map(fn edge ->
          case direction do
            :out when edge.from_node_id == node_id -> [edge.to_node_id]
            :in when edge.to_node_id == node_id -> [edge.from_node_id]
            :both -> [edge.from_node_id, edge.to_node_id]
            _ -> []
          end
        end)
      end)
      |> Enum.uniq()
      |> Enum.reject(&MapSet.member?(visited, &1))

    new_visited = Enum.reduce(next_nodes, visited, &MapSet.put(&2, &1))

    current_result = MapSet.to_list(visited)
    next_result = traverse_recursive(storage, next_nodes, new_visited, depth + 1, max_depth, direction)

    (current_result ++ next_result) |> Enum.uniq()
  end

  @doc """
  Find shortest path between two nodes.
  """
  @spec shortest_path(Graph.t(), Node.id(), Node.id(), keyword()) :: {:ok, [Node.t()]} | {:error, :no_path}
  def shortest_path(%Graph{storage: storage} = _graph, from_id, to_id, _opts \\ []) do
    case bfs_path(storage, from_id, to_id) do
      {:ok, path} ->
        nodes = Enum.map(path, fn node_id ->
          {:ok, node} = Storage.get_node(storage, node_id)
          node
        end)
        {:ok, nodes}

      {:error, :no_path} ->
        {:error, :no_path}
    end
  end

  defp bfs_path(_storage, from_id, to_id) when from_id == to_id do
    {:ok, [from_id]}
  end

  defp bfs_path(storage, from_id, to_id) do
    queue = [{from_id, [from_id]}]
    visited = MapSet.new([from_id])

    bfs_search(storage, queue, visited, to_id)
  end

  defp bfs_search(_storage, [], _visited, _target) do
    {:error, :no_path}
  end

  defp bfs_search(storage, [{current_id, path} | rest], visited, target) do
    if current_id == target do
      {:ok, Enum.reverse(path)}
    else
      neighbors = Storage.get_edges_for_node(storage, current_id)
      |> Enum.flat_map(fn edge ->
        cond do
          edge.from_node_id == current_id -> [edge.to_node_id]
          edge.to_node_id == current_id -> [edge.from_node_id]
          true -> []
        end
      end)
      |> Enum.reject(&MapSet.member?(visited, &1))

      new_queue_items = Enum.map(neighbors, fn neighbor_id ->
        {neighbor_id, [neighbor_id | path]}
      end)

      new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))
      new_queue = rest ++ new_queue_items

      bfs_search(storage, new_queue, new_visited, target)
    end
  end
end
