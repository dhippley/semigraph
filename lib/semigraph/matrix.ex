defmodule Semigraph.Matrix do
  @moduledoc """
  Matrix representation abstraction over Nx for graph algebra operations.

  Provides sparse and dense matrix representations of graphs, enabling
  algebraic operations for pathfinding, centrality, and other graph algorithms.
  """

  alias Semigraph.{Graph, Semiring}

  @type matrix_type :: :dense | :sparse
  @type t :: %__MODULE__{
          data: Nx.Tensor.t(),
          type: matrix_type(),
          node_mapping: %{term() => non_neg_integer()},
          dimensions: {pos_integer(), pos_integer()}
        }

  defstruct [:data, :type, :node_mapping, :dimensions]

  @doc """
  Creates an adjacency matrix from a graph.
  """
  @spec from_graph(Graph.t(), matrix_type()) :: {:ok, t()} | {:error, term()}
  def from_graph(%Graph{} = graph, type \\ :dense) do
    try do
      # Get all nodes to create mapping
      nodes = Graph.list_nodes(graph)
      edges = Graph.list_edges(graph)

      if Enum.empty?(nodes) do
        {:ok, empty_matrix(type)}
      else
        # Create node ID to matrix index mapping
        node_mapping =
          nodes
          |> Enum.with_index()
          |> Enum.into(%{}, fn {node, idx} -> {node.id, idx} end)

        size = length(nodes)

        # Create adjacency matrix based on type
        matrix_data = case type do
          :dense -> create_dense_matrix(edges, node_mapping, size)
          :sparse -> create_sparse_matrix(edges, node_mapping, size)
        end

        matrix = %__MODULE__{
          data: matrix_data,
          type: type,
          node_mapping: node_mapping,
          dimensions: {size, size}
        }

        {:ok, matrix}
      end
    rescue
      error -> {:error, error}
    end
  end

  defp empty_matrix(type) do
    # Nx doesn't support 0x0 tensors, so we'll use a special representation
    # We'll use nil for the data field and handle this case in other functions
    %__MODULE__{
      data: nil,
      type: type,
      node_mapping: %{},
      dimensions: {0, 0}
    }
  end

  defp create_dense_matrix(edges, node_mapping, size) do
    # Create list of matrix elements
    elements =
      for i <- 0..(size-1), j <- 0..(size-1) do
        # Find edge from i to j
        from_node = get_node_by_index(node_mapping, i)
        to_node = get_node_by_index(node_mapping, j)

        edge = Enum.find(edges, fn e ->
          e.from_node_id == from_node && e.to_node_id == to_node
        end)

        if edge do
          get_edge_weight(edge)
        else
          0
        end
      end

    # Convert to Nx tensor
    elements
    |> Enum.chunk_every(size)
    |> Nx.tensor()
  end

  defp get_node_by_index(node_mapping, index) do
    node_mapping
    |> Enum.find(fn {_node_id, idx} -> idx == index end)
    |> case do
      {node_id, _} -> node_id
      nil -> nil
    end
  end

  defp create_sparse_matrix(edges, node_mapping, size) do
    # For now, create dense and convert (Nx sparse support is evolving)
    create_dense_matrix(edges, node_mapping, size)
  end

  defp get_edge_weight(edge) do
    # Check for weight property, default to 1
    Map.get(edge.properties, "weight", Map.get(edge.properties, :weight, 1))
  end

  @doc """
  Converts between sparse and dense representations.
  """
  @spec convert(t(), matrix_type()) :: t()
  def convert(%__MODULE__{} = matrix, target_type) do
    if matrix.type == target_type do
      matrix
    else
      # For now, both types use the same underlying representation
      %{matrix | type: target_type}
    end
  end

  @doc """
  Matrix multiplication for path operations.
  """
  @spec multiply(t(), t()) :: t()
  def multiply(%__MODULE__{data: nil} = matrix_a, %__MODULE__{data: nil}) do
    # Empty matrix multiplication
    matrix_a
  end
  def multiply(%__MODULE__{data: nil} = matrix_a, %__MODULE__{}) do
    # Empty * non-empty = empty
    matrix_a
  end
  def multiply(%__MODULE__{}, %__MODULE__{data: nil} = matrix_b) do
    # Non-empty * empty = empty
    matrix_b
  end
  def multiply(%__MODULE__{data: data_a, node_mapping: mapping_a} = matrix_a,
               %__MODULE__{data: data_b, node_mapping: mapping_b}) do
    # Ensure compatible dimensions and mappings
    if mapping_a == mapping_b do
      result_data = Nx.dot(data_a, data_b)
      %{matrix_a | data: result_data}
    else
      raise ArgumentError, "Cannot multiply matrices with different node mappings"
    end
  end

  @doc """
  Matrix power for k-hop paths.
  """
  @spec power(t(), pos_integer()) :: t()
  def power(%__MODULE__{data: nil} = matrix, _k), do: matrix
  def power(%__MODULE__{} = matrix, 1), do: matrix
  def power(%__MODULE__{} = matrix, k) when k > 1 do
    # Repeated matrix multiplication
    Enum.reduce(2..k, matrix, fn _, acc -> multiply(acc, matrix) end)
  end

  @doc """
  Matrix transpose.
  """
  @spec transpose(t()) :: t()
  def transpose(%__MODULE__{data: nil} = matrix), do: matrix
  def transpose(%__MODULE__{data: data} = matrix) do
    %{matrix | data: Nx.transpose(data)}
  end

  @doc """
  Elementwise operations with custom semiring.
  """
  @spec elementwise_op(t(), t(), (term(), term() -> term())) :: t()
  def elementwise_op(%__MODULE__{data: nil} = matrix_a, %__MODULE__{data: nil}, _operation) do
    matrix_a
  end
  def elementwise_op(%__MODULE__{data: nil} = matrix_a, %__MODULE__{}, _operation) do
    matrix_a
  end
  def elementwise_op(%__MODULE__{}, %__MODULE__{data: nil} = matrix_b, _operation) do
    matrix_b
  end
  def elementwise_op(%__MODULE__{data: data_a, node_mapping: mapping_a} = matrix_a,
                     %__MODULE__{data: data_b, node_mapping: mapping_b}, _operation) do
    if mapping_a == mapping_b do
      # For now, use simple addition as example - custom operations need more work
      result_data = Nx.add(data_a, data_b)
      %{matrix_a | data: result_data}
    else
      raise ArgumentError, "Cannot perform elementwise operation on matrices with different node mappings"
    end
  end

  @doc """
  Extract subgraph matrix for a set of nodes.
  """
  @spec subgraph(t(), [term()]) :: t()
  def subgraph(%__MODULE__{data: data, node_mapping: node_mapping} = matrix, node_ids) do
    # Get indices for the selected nodes
    indices =
      node_ids
      |> Enum.map(&Map.get(node_mapping, &1))
      |> Enum.filter(& &1 != nil)
      |> Enum.sort()

    if Enum.empty?(indices) do
      empty_matrix(matrix.type)
    else
      # Extract submatrix
      submatrix_data = extract_submatrix(data, indices)

      # Create new node mapping
      new_mapping =
        node_ids
        |> Enum.with_index()
        |> Enum.into(%{})

      size = length(indices)

      %{matrix |
        data: submatrix_data,
        node_mapping: new_mapping,
        dimensions: {size, size}
      }
    end
  end

  defp extract_submatrix(data, indices) do
    # Simple extraction - get rows and columns at specified indices
    # This is a basic implementation
    rows = Enum.map(indices, fn i -> Nx.slice_along_axis(data, i, 1, axis: 0) end)
    matrix_rows = Nx.concatenate(rows, axis: 0)

    cols = Enum.map(indices, fn j -> Nx.slice_along_axis(matrix_rows, j, 1, axis: 1) end)
    Nx.concatenate(cols, axis: 1)
  end

  @doc """
  Get matrix dimensions.
  """
  @spec size(t()) :: {pos_integer(), pos_integer()}
  def size(%__MODULE__{dimensions: dims}), do: dims

  @doc """
  Convert matrix back to edge list representation.
  """
  @spec to_edges(t()) :: [{term(), term(), number()}]
  def to_edges(%__MODULE__{dimensions: {0, 0}}) do
    # Empty matrix case
    []
  end

  def to_edges(%__MODULE__{data: data, node_mapping: node_mapping}) do
    # Create reverse mapping (index -> node_id)
    reverse_mapping =
      node_mapping
      |> Enum.into(%{}, fn {node_id, idx} -> {idx, node_id} end)

    # Extract non-zero entries
    {rows, cols} = Nx.shape(data)

    for i <- 0..(rows-1), j <- 0..(cols-1) do
      weight = data |> Nx.to_flat_list() |> Enum.at(i * cols + j)

      if weight != 0 do
        from_node = Map.get(reverse_mapping, i)
        to_node = Map.get(reverse_mapping, j)
        {from_node, to_node, weight}
      else
        nil
      end
    end
    |> Enum.filter(& &1 != nil)
  end

  @doc """
  Matrix multiplication using a specific semiring.
  """
  @spec semiring_multiply(t(), t(), Semiring.t()) :: t()
  def semiring_multiply(%__MODULE__{data: nil} = matrix_a, %__MODULE__{data: nil}, _semiring) do
    # Empty matrix multiplication
    matrix_a
  end
  def semiring_multiply(%__MODULE__{data: nil} = matrix_a, %__MODULE__{}, _semiring) do
    # Empty * non-empty = empty
    matrix_a
  end
  def semiring_multiply(%__MODULE__{}, %__MODULE__{data: nil} = matrix_b, _semiring) do
    # Non-empty * empty = empty
    matrix_b
  end
  def semiring_multiply(%__MODULE__{data: data_a, node_mapping: mapping_a} = matrix_a,
                        %__MODULE__{data: data_b, node_mapping: mapping_b}, semiring) do
    # Ensure compatible dimensions and mappings
    if mapping_a == mapping_b do
      result_data = Semiring.matrix_multiply(semiring, data_a, data_b)
      %{matrix_a | data: result_data}
    else
      raise ArgumentError, "Cannot multiply matrices with different node mappings"
    end
  end

  @doc """
  Matrix power using a specific semiring.
  """
  @spec semiring_power(t(), pos_integer(), Semiring.t()) :: t()
  def semiring_power(%__MODULE__{data: nil} = matrix, _k, _semiring), do: matrix
  def semiring_power(%__MODULE__{} = matrix, 1, _semiring), do: matrix
  def semiring_power(%__MODULE__{} = matrix, k, semiring) when k > 1 do
    # Repeated matrix multiplication using semiring
    Enum.reduce(2..k, matrix, fn _, acc ->
      semiring_multiply(acc, matrix, semiring)
    end)
  end
end
