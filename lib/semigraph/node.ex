defmodule Semigraph.Node do
  @moduledoc """
  Represents a node in the property graph.

  Nodes have an ID, labels, and arbitrary properties.
  """

  @type id :: term()
  @type label :: String.t()
  @type properties :: map()

  @type t :: %__MODULE__{
          id: id(),
          labels: [label()],
          properties: properties(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [:id, :labels, :properties, :created_at, :updated_at]

  @doc """
  Creates a new node with given ID, labels, and properties.
  """
  @spec new(id(), [label()], properties()) :: t()
  def new(id, labels \\ [], properties \\ %{}) do
    now = DateTime.utc_now()

    %__MODULE__{
      id: id,
      labels: labels,
      properties: properties,
      created_at: now,
      updated_at: now
    }
  end

  @doc """
  Adds a label to the node.
  """
  @spec add_label(t(), label()) :: t()
  def add_label(%__MODULE__{labels: labels} = node, label) do
    %{node | labels: [label | labels] |> Enum.uniq(), updated_at: DateTime.utc_now()}
  end

  @doc """
  Removes a label from the node.
  """
  @spec remove_label(t(), label()) :: t()
  def remove_label(%__MODULE__{labels: labels} = node, label) do
    %{node | labels: List.delete(labels, label), updated_at: DateTime.utc_now()}
  end

  @doc """
  Sets a property on the node.
  """
  @spec set_property(t(), String.t(), term()) :: t()
  def set_property(%__MODULE__{properties: props} = node, key, value) do
    %{node | properties: Map.put(props, key, value), updated_at: DateTime.utc_now()}
  end

  @doc """
  Gets a property value from the node.
  """
  @spec get_property(t(), String.t(), term()) :: term()
  def get_property(%__MODULE__{properties: props}, key, default \\ nil) do
    Map.get(props, key, default)
  end

  @doc """
  Checks if node has a specific label.
  """
  @spec has_label?(t(), label()) :: boolean()
  def has_label?(%__MODULE__{labels: labels}, label) do
    label in labels
  end
end
