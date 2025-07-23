defmodule Semigraph.Storage do
  @moduledoc """
  ETS-based storage layer for nodes and edges with indexing support.

  Manages the low-level storage operations, indexing strategies, and provides
  concurrent access to graph data.
  """

  alias Semigraph.{Node, Edge}

  @type table_name :: atom()
  @type index_name :: atom()

  @type t :: %__MODULE__{
          nodes_table: table_name(),
          edges_table: table_name(),
          indexes: %{index_name() => table_name()},
          options: keyword()
        }

  defstruct [:nodes_table, :edges_table, :indexes, :options]

  @doc """
  Creates a new storage instance with ETS tables.
  """
  @spec new(String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def new(name, opts \\ []) do
    nodes_table = :"#{name}_nodes"
    edges_table = :"#{name}_edges"
    label_index = :"#{name}_labels"
    property_index = :"#{name}_properties"
    adjacency_index = :"#{name}_adjacency"

    table_opts = [:set, :public, :named_table, {:read_concurrency, true}, {:write_concurrency, true}]

    try do
      # Create main tables
      ^nodes_table = :ets.new(nodes_table, table_opts)
      ^edges_table = :ets.new(edges_table, table_opts)

      # Create index tables
      ^label_index = :ets.new(label_index, [:bag, :public, :named_table, {:read_concurrency, true}])
      ^property_index = :ets.new(property_index, [:bag, :public, :named_table, {:read_concurrency, true}])
      ^adjacency_index = :ets.new(adjacency_index, table_opts)

      storage = %__MODULE__{
        nodes_table: nodes_table,
        edges_table: edges_table,
        indexes: %{
          labels: label_index,
          properties: property_index,
          adjacency: adjacency_index
        },
        options: opts
      }

      {:ok, storage}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Stores a node in the ETS table and updates indexes.
  """
  @spec put_node(t(), Node.t()) :: :ok | {:error, term()}
  def put_node(%__MODULE__{nodes_table: nodes_table, indexes: indexes} = _storage, %Node{} = node) do
    try do
      # Store node in main table
      :ets.insert(nodes_table, {node.id, node})

      # Update label indexes
      label_index = Map.get(indexes, :labels)
      if label_index do
        Enum.each(node.labels, fn label ->
          :ets.insert(label_index, {label, node.id})
        end)
      end

      # Update property indexes
      property_index = Map.get(indexes, :properties)
      if property_index do
        Enum.each(node.properties, fn {key, value} ->
          :ets.insert(property_index, {{key, value}, node.id})
        end)
      end

      :ok
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Retrieves a node by ID.
  """
  @spec get_node(t(), Node.id()) :: {:ok, Node.t()} | {:error, :not_found}
  def get_node(%__MODULE__{nodes_table: nodes_table}, node_id) do
    case :ets.lookup(nodes_table, node_id) do
      [{^node_id, node}] -> {:ok, node}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Stores an edge in the ETS table and updates indexes.
  """
  @spec put_edge(t(), Edge.t()) :: :ok | {:error, term()}
  def put_edge(%__MODULE__{edges_table: edges_table, indexes: indexes} = _storage, %Edge{} = edge) do
    try do
      # Store edge in main table
      :ets.insert(edges_table, {edge.id, edge})

      # Update adjacency index
      adjacency_index = Map.get(indexes, :adjacency)
      if adjacency_index do
        # Update outgoing edges for from_node
        case :ets.lookup(adjacency_index, edge.from_node_id) do
          [{_, adjacency}] ->
            updated_adjacency = %{adjacency | out: [edge.id | adjacency.out]}
            :ets.insert(adjacency_index, {edge.from_node_id, updated_adjacency})
          [] ->
            :ets.insert(adjacency_index, {edge.from_node_id, %{in: [], out: [edge.id]}})
        end

        # Update incoming edges for to_node
        case :ets.lookup(adjacency_index, edge.to_node_id) do
          [{_, adjacency}] ->
            updated_adjacency = %{adjacency | in: [edge.id | adjacency.in]}
            :ets.insert(adjacency_index, {edge.to_node_id, updated_adjacency})
          [] ->
            :ets.insert(adjacency_index, {edge.to_node_id, %{in: [edge.id], out: []}})
        end
      end

      :ok
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Retrieves an edge by ID.
  """
  @spec get_edge(t(), Edge.id()) :: {:ok, Edge.t()} | {:error, :not_found}
  def get_edge(%__MODULE__{edges_table: edges_table}, edge_id) do
    case :ets.lookup(edges_table, edge_id) do
      [{^edge_id, edge}] -> {:ok, edge}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Finds all edges connected to a node.
  """
  @spec get_edges_for_node(t(), Node.id()) :: [Edge.t()]
  def get_edges_for_node(%__MODULE__{edges_table: edges_table, indexes: indexes}, node_id) do
    case Map.get(indexes, :adjacency) do
      nil ->
        # Fallback: scan all edges (less efficient)
        :ets.tab2list(edges_table)
        |> Enum.filter(fn {_id, edge} ->
          edge.from_node_id == node_id or edge.to_node_id == node_id
        end)
        |> Enum.map(fn {_id, edge} -> edge end)

      adjacency_index ->
        case :ets.lookup(adjacency_index, node_id) do
          [{^node_id, %{in: in_edges, out: out_edges}}] ->
            all_edge_ids = in_edges ++ out_edges
            all_edge_ids
            |> Enum.map(fn edge_id ->
              case :ets.lookup(edges_table, edge_id) do
                [{^edge_id, edge}] -> edge
                [] -> nil
              end
            end)
            |> Enum.filter(& &1)
          [] ->
            []
        end
    end
  end

  @doc """
  Creates an index on node properties or labels.
  """
  @spec create_index(t(), index_name(), :labels | :properties, String.t() | nil) :: {:ok, t()} | {:error, term()}
  def create_index(%__MODULE__{} = storage, _index_name, :labels, _property_key) do
    # Labels index already created in new/2
    {:ok, storage}
  end

  def create_index(%__MODULE__{} = storage, _index_name, :properties, _property_key) do
    # Properties index already created in new/2
    {:ok, storage}
  end

  @doc """
  Queries nodes using an index.
  """
  @spec query_index(t(), index_name(), term()) :: [Node.t()]
  def query_index(%__MODULE__{nodes_table: nodes_table, indexes: indexes}, :labels, label) do
    case Map.get(indexes, :labels) do
      nil -> []
      label_index ->
        :ets.lookup(label_index, label)
        |> Enum.map(fn {^label, node_id} ->
          case :ets.lookup(nodes_table, node_id) do
            [{^node_id, node}] -> node
            [] -> nil
          end
        end)
        |> Enum.filter(& &1)
    end
  end

  def query_index(%__MODULE__{nodes_table: nodes_table, indexes: indexes}, :properties, {key, value}) do
    case Map.get(indexes, :properties) do
      nil -> []
      property_index ->
        :ets.lookup(property_index, {key, value})
        |> Enum.map(fn {{^key, ^value}, node_id} ->
          case :ets.lookup(nodes_table, node_id) do
            [{^node_id, node}] -> node
            [] -> nil
          end
        end)
        |> Enum.filter(& &1)
    end
  end

  def query_index(_storage, _index_name, _value) do
    []
  end

  @doc """
  Deletes a node and updates all indexes.
  """
  @spec delete_node(t(), Node.id()) :: :ok | {:error, term()}
  def delete_node(%__MODULE__{nodes_table: nodes_table, indexes: indexes} = storage, node_id) do
    try do
      # First get the node to clean up indexes
      case get_node(storage, node_id) do
        {:ok, node} ->
          # Remove from label indexes
          if label_index = Map.get(indexes, :labels) do
            Enum.each(node.labels, fn label ->
              :ets.delete_object(label_index, {label, node_id})
            end)
          end

          # Remove from property indexes
          if property_index = Map.get(indexes, :properties) do
            Enum.each(node.properties, fn {key, value} ->
              :ets.delete_object(property_index, {{key, value}, node_id})
            end)
          end

          # Remove from adjacency index
          if adjacency_index = Map.get(indexes, :adjacency) do
            :ets.delete(adjacency_index, node_id)
          end

          # Remove node from main table
          :ets.delete(nodes_table, node_id)
          :ok

        {:error, :not_found} ->
          {:error, :not_found}
      end
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Deletes an edge and updates all indexes.
  """
  @spec delete_edge(t(), Edge.id()) :: :ok | {:error, term()}
  def delete_edge(%__MODULE__{edges_table: edges_table, indexes: indexes} = storage, edge_id) do
    try do
      case get_edge(storage, edge_id) do
        {:ok, edge} ->
          # Update adjacency index
          if adjacency_index = Map.get(indexes, :adjacency) do
            # Remove from from_node's outgoing edges
            case :ets.lookup(adjacency_index, edge.from_node_id) do
              [{_, adjacency}] ->
                updated_adjacency = %{adjacency | out: List.delete(adjacency.out, edge_id)}
                :ets.insert(adjacency_index, {edge.from_node_id, updated_adjacency})
              [] -> :ok
            end

            # Remove from to_node's incoming edges
            case :ets.lookup(adjacency_index, edge.to_node_id) do
              [{_, adjacency}] ->
                updated_adjacency = %{adjacency | in: List.delete(adjacency.in, edge_id)}
                :ets.insert(adjacency_index, {edge.to_node_id, updated_adjacency})
              [] -> :ok
            end
          end

          # Remove edge from main table
          :ets.delete(edges_table, edge_id)
          :ok

        {:error, :not_found} ->
          {:error, :not_found}
      end
    rescue
      error -> {:error, error}
    end
  end
end
