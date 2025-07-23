defmodule Semigraph.Graph do
  @moduledoc """
  Core graph data structure and operations.

  Manages the overall graph state, coordinates between storage and indexing layers,
  and provides the primary API for graph manipulation.
  """

  alias Semigraph.{Node, Edge, Storage}

  @type t :: %__MODULE__{
          name: String.t(),
          storage: Storage.t(),
          metadata: map()
        }

  defstruct [:name, :storage, :metadata]

  @doc """
  Creates a new empty graph.
  """
  @spec new(String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def new(name \\ "default", opts \\ []) do
    case Storage.new(name, opts) do
      {:ok, storage} ->
        graph = %__MODULE__{
          name: name,
          storage: storage,
          metadata: %{created_at: DateTime.utc_now()}
        }
        {:ok, graph}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Adds a node to the graph.
  """
  @spec add_node(t(), Node.t()) :: {:ok, t()} | {:error, term()}
  def add_node(%__MODULE__{storage: storage} = graph, %Node{} = node) do
    case Storage.put_node(storage, node) do
      :ok -> {:ok, graph}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Adds an edge to the graph.
  """
  @spec add_edge(t(), Edge.t()) :: {:ok, t()} | {:error, term()}
  def add_edge(%__MODULE__{storage: storage} = graph, %Edge{} = edge) do
    # Validate that both nodes exist
    with {:ok, _from_node} <- Storage.get_node(storage, edge.from_node_id),
         {:ok, _to_node} <- Storage.get_node(storage, edge.to_node_id) do
      case Storage.put_edge(storage, edge) do
        :ok -> {:ok, graph}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :not_found} -> {:error, :node_not_found}
      error -> error
    end
  end

  @doc """
  Retrieves a node by ID.
  """
  @spec get_node(t(), term()) :: {:ok, Node.t()} | {:error, :not_found}
  def get_node(%__MODULE__{storage: storage}, node_id) do
    Storage.get_node(storage, node_id)
  end

  @doc """
  Deletes a node and all connected edges.
  """
  @spec delete_node(t(), term()) :: {:ok, t()} | {:error, term()}
  def delete_node(%__MODULE__{storage: storage} = graph, node_id) do
    # First delete all connected edges
    edges = Storage.get_edges_for_node(storage, node_id)
    Enum.each(edges, fn edge ->
      Storage.delete_edge(storage, edge.id)
    end)

    # Then delete the node
    case Storage.delete_node(storage, node_id) do
      :ok -> {:ok, graph}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists all nodes matching optional filters.
  """
  @spec list_nodes(t(), keyword()) :: [Node.t()]
  def list_nodes(%__MODULE__{storage: storage}, filters \\ []) do
    case filters do
      [] ->
        # Return all nodes
        :ets.tab2list(storage.nodes_table)
        |> Enum.map(fn {_id, node} -> node end)

      [label: label] ->
        Storage.query_index(storage, :labels, label)

      [property: {key, value}] ->
        Storage.query_index(storage, :properties, {key, value})

      _ ->
        # For complex filters, fall back to scanning all nodes
        :ets.tab2list(storage.nodes_table)
        |> Enum.map(fn {_id, node} -> node end)
        |> apply_filters(filters)
    end
  end

  # Helper function to apply filters when not using indexes
  defp apply_filters(nodes, filters) do
    Enum.filter(nodes, fn node ->
      Enum.all?(filters, fn
        {:label, label} -> label in node.labels
        {:property, {key, value}} -> Map.get(node.properties, key) == value
        _ -> true
      end)
    end)
  end

  @doc """
  Lists all edges matching optional filters.
  """
  @spec list_edges(t(), keyword()) :: [Edge.t()]
  def list_edges(%__MODULE__{storage: storage}, filters \\ []) do
    edges = :ets.tab2list(storage.edges_table)
    |> Enum.map(fn {_id, edge} -> edge end)

    case filters do
      [] -> edges
      _ -> apply_edge_filters(edges, filters)
    end
  end

  defp apply_edge_filters(edges, filters) do
    Enum.filter(edges, fn edge ->
      Enum.all?(filters, fn
        {:type, rel_type} -> edge.relationship_type == rel_type
        {:from, node_id} -> edge.from_node_id == node_id
        {:to, node_id} -> edge.to_node_id == node_id
        {:property, {key, value}} -> Map.get(edge.properties, key) == value
        _ -> true
      end)
    end)
  end
end
