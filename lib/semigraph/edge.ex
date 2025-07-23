defmodule Semigraph.Edge do
  @moduledoc """
  Represents an edge (relationship) in the property graph.

  Edges connect two nodes with a relationship type and optional properties.
  """

  alias Semigraph.Node

  @type id :: term()
  @type relationship_type :: String.t()
  @type properties :: map()

  @type t :: %__MODULE__{
          id: id(),
          from_node_id: Node.id(),
          to_node_id: Node.id(),
          relationship_type: relationship_type(),
          properties: properties(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [:id, :from_node_id, :to_node_id, :relationship_type, :properties, :created_at, :updated_at]

  @doc """
  Creates a new edge between two nodes.
  """
  @spec new(id(), Node.id(), Node.id(), relationship_type(), properties()) :: t()
  def new(id, from_node_id, to_node_id, relationship_type, properties \\ %{}) do
    now = DateTime.utc_now()

    %__MODULE__{
      id: id,
      from_node_id: from_node_id,
      to_node_id: to_node_id,
      relationship_type: relationship_type,
      properties: properties,
      created_at: now,
      updated_at: now
    }
  end

  @doc """
  Sets a property on the edge.
  """
  @spec set_property(t(), String.t(), term()) :: t()
  def set_property(%__MODULE__{properties: props} = edge, key, value) do
    %{edge | properties: Map.put(props, key, value), updated_at: DateTime.utc_now()}
  end

  @doc """
  Gets a property value from the edge.
  """
  @spec get_property(t(), String.t(), term()) :: term()
  def get_property(%__MODULE__{properties: props}, key, default \\ nil) do
    Map.get(props, key, default)
  end

  @doc """
  Returns the reverse direction of this edge.
  """
  @spec reverse(t()) :: t()
  def reverse(%__MODULE__{from_node_id: from_id, to_node_id: to_id} = edge) do
    %{edge | from_node_id: to_id, to_node_id: from_id, updated_at: DateTime.utc_now()}
  end
end
