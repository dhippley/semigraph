defmodule Semigraph.Query.AST do
  @moduledoc """
  Abstract Syntax Tree representation for graph queries.

  Supports a Cypher-like query language with MATCH, WHERE, and RETURN clauses.
  """

  @type variable :: String.t()
  @type label :: String.t()
  @type property_key :: String.t()
  @type property_value :: term()
  @type relationship_type :: String.t()

  @type node_pattern :: %{
    variable: variable() | nil,
    labels: [label()],
    properties: %{property_key() => property_value()}
  }

  @type edge_pattern :: %{
    variable: variable() | nil,
    relationship_type: relationship_type() | nil,
    properties: %{property_key() => property_value()},
    direction: :outgoing | :incoming | :undirected,
    min_hops: pos_integer() | nil,
    max_hops: pos_integer() | nil
  }

  @type path_pattern :: %{
    nodes: [node_pattern()],
    edges: [edge_pattern()]
  }

  @type comparison_op :: :eq | :neq | :gt | :gte | :lt | :lte | :in | :contains
  @type logical_op :: :and | :or | :not

  @type condition ::
    %{type: :comparison, left: term(), op: comparison_op(), right: term()} |
    %{type: :logical, op: logical_op(), conditions: [condition()]} |
    %{type: :property_exists, variable: variable(), property: property_key()}

  @type return_item ::
    %{type: :variable, variable: variable()} |
    %{type: :property, variable: variable(), property: property_key()} |
    %{type: :aggregation, function: atom(), variable: variable(), property: property_key() | nil}

  @type t :: %__MODULE__{
    match_patterns: [path_pattern()],
    where_conditions: [condition()],
    return_items: [return_item()],
    limit: pos_integer() | nil,
    skip: non_neg_integer() | nil,
    order_by: [{variable(), :asc | :desc}]
  }

  defstruct [
    :match_patterns,
    :where_conditions,
    :return_items,
    :limit,
    :skip,
    :order_by
  ]

  @doc """
  Creates a new empty query AST.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      match_patterns: [],
      where_conditions: [],
      return_items: [],
      limit: nil,
      skip: nil,
      order_by: []
    }
  end

  @doc """
  Adds a MATCH pattern to the query.
  """
  @spec add_match_pattern(t(), path_pattern()) :: t()
  def add_match_pattern(%__MODULE__{match_patterns: patterns} = ast, pattern) do
    %{ast | match_patterns: patterns ++ [pattern]}
  end

  @doc """
  Adds a WHERE condition to the query.
  """
  @spec add_where_condition(t(), condition()) :: t()
  def add_where_condition(%__MODULE__{where_conditions: conditions} = ast, condition) do
    %{ast | where_conditions: conditions ++ [condition]}
  end

  @doc """
  Adds a RETURN item to the query.
  """
  @spec add_return_item(t(), return_item()) :: t()
  def add_return_item(%__MODULE__{return_items: items} = ast, item) do
    %{ast | return_items: items ++ [item]}
  end

  @doc """
  Sets the RETURN items for the query.
  """
  @spec set_return_items(t(), [return_item()]) :: t()
  def set_return_items(%__MODULE__{} = ast, items) do
    %{ast | return_items: items}
  end

  @doc """
  Sets the LIMIT clause.
  """
  @spec set_limit(t(), pos_integer()) :: t()
  def set_limit(%__MODULE__{} = ast, limit) do
    %{ast | limit: limit}
  end

  @doc """
  Sets the SKIP clause.
  """
  @spec set_skip(t(), non_neg_integer()) :: t()
  def set_skip(%__MODULE__{} = ast, skip) do
    %{ast | skip: skip}
  end

  @doc """
  Adds an ORDER BY clause.
  """
  @spec add_order_by(t(), variable(), :asc | :desc) :: t()
  def add_order_by(%__MODULE__{order_by: order_by} = ast, variable, direction) do
    %{ast | order_by: order_by ++ [{variable, direction}]}
  end
end
