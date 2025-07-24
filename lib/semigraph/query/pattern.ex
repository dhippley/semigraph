defmodule Semigraph.Query.Pattern do
  @moduledoc """
  Utilities for working with query patterns and matching them against graph elements.
  """

  alias Semigraph.{Node, Edge}
  alias Semigraph.Query.AST

  @doc """
  Creates a simple node pattern.
  """
  @spec node(String.t() | nil, [String.t()], map()) :: AST.node_pattern()
  def node(variable \\ nil, labels \\ [], properties \\ %{}) do
    %{
      variable: variable,
      labels: labels,
      properties: properties
    }
  end

  @doc """
  Creates an edge pattern.
  """
  @spec edge(String.t() | nil, String.t() | nil, map(), atom(), pos_integer() | nil, pos_integer() | nil) :: AST.edge_pattern()
  def edge(variable \\ nil, relationship_type \\ nil, properties \\ %{}, direction \\ :outgoing, min_hops \\ nil, max_hops \\ nil) do
    %{
      variable: variable,
      relationship_type: relationship_type,
      properties: properties,
      direction: direction,
      min_hops: min_hops,
      max_hops: max_hops
    }
  end

  @doc """
  Creates a path pattern from alternating nodes and edges.
  """
  @spec path([AST.node_pattern() | AST.edge_pattern()]) :: AST.path_pattern()
  def path(elements) do
    {nodes, edges} =
      elements
      |> Enum.with_index()
      |> Enum.split_with(fn {_element, index} -> rem(index, 2) == 0 end)

    %{
      nodes: Enum.map(nodes, fn {node, _index} -> node end),
      edges: Enum.map(edges, fn {edge, _index} -> edge end)
    }
  end

  @doc """
  Checks if a node matches a node pattern.
  """
  @spec matches_node?(Node.t(), AST.node_pattern()) :: boolean()
  def matches_node?(%Node{} = node, pattern) do
    labels_match?(node, pattern.labels) and
    properties_match?(node.properties, pattern.properties)
  end

  @doc """
  Checks if an edge matches an edge pattern.
  """
  @spec matches_edge?(Edge.t(), AST.edge_pattern()) :: boolean()
  def matches_edge?(%Edge{} = edge, pattern) do
    relationship_type_matches?(edge, pattern.relationship_type) and
    properties_match?(edge.properties, pattern.properties)
  end

  @doc """
  Creates a comparison condition.
  """
  @spec compare(term(), AST.comparison_op(), term()) :: AST.condition()
  def compare(left, op, right) do
    %{type: :comparison, left: left, op: op, right: right}
  end

  @doc """
  Creates a logical AND condition.
  """
  @spec and_condition([AST.condition()]) :: AST.condition()
  def and_condition(conditions) do
    %{type: :logical, op: :and, conditions: conditions}
  end

  @doc """
  Creates a logical OR condition.
  """
  @spec or_condition([AST.condition()]) :: AST.condition()
  def or_condition(conditions) do
    %{type: :logical, op: :or, conditions: conditions}
  end

  @doc """
  Creates a property existence condition.
  """
  @spec property_exists(String.t(), String.t()) :: AST.condition()
  def property_exists(variable, property) do
    %{type: :property_exists, variable: variable, property: property}
  end

  @doc """
  Creates a return variable item.
  """
  @spec return_variable(String.t()) :: AST.return_item()
  def return_variable(variable) do
    %{type: :variable, variable: variable}
  end

  @doc """
  Creates a return property item.
  """
  @spec return_property(String.t(), String.t()) :: AST.return_item()
  def return_property(variable, property) do
    %{type: :property, variable: variable, property: property}
  end

  @doc """
  Creates a return aggregation item.
  """
  @spec return_aggregation(atom(), String.t(), String.t() | nil) :: AST.return_item()
  def return_aggregation(function, variable, property \\ nil) do
    %{type: :aggregation, function: function, variable: variable, property: property}
  end

  # Private helper functions

  defp labels_match?(_node, []), do: true
  defp labels_match?(%Node{labels: node_labels}, pattern_labels) do
    Enum.all?(pattern_labels, &(&1 in node_labels))
  end

  defp properties_match?(_node_props, pattern_props) when map_size(pattern_props) == 0, do: true
  defp properties_match?(node_props, pattern_props) do
    Enum.all?(pattern_props, fn {key, value} ->
      Map.get(node_props, key) == value
    end)
  end

  defp relationship_type_matches?(_edge, nil), do: true
  defp relationship_type_matches?(%Edge{relationship_type: edge_type}, pattern_type) do
    edge_type == pattern_type
  end
end
