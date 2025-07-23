defmodule Semigraph.Matrix do
  @moduledoc """
  Matrix representation abstraction over Nx for graph algebra operations.

  Provides sparse and dense matrix representations of graphs, enabling
  algebraic operations for pathfinding, centrality, and other graph algorithms.

  ## Current Implementation

  - **Dense matrices**: Full Nx tensor representation for small/dense graphs
  - **Sparse matrices**: COO (Coordinate) format for memory-efficient sparse graphs
  - **Bidirectional conversion**: Seamless sparse ↔ dense transformations
  - **Semiring integration**: Custom algebraic structures for specialized algorithms

  ## 🔄 Potential Future Optimizations

  - **CSR Format**: For faster row operations
  - **Native Sparse Multiplication**: Avoid dense conversion
  - **Sparse Semiring Operations**: Direct sparse matrix algebra
  - **Memory-Mapped Storage**: For very large sparse matrices
  """

  alias Semigraph.{Graph, Semiring}

  @type matrix_type :: :dense | :sparse
  @type sparse_data :: %{
    indices: Nx.Tensor.t(),  # Shape: {nnz, 2} - row, col coordinates
    values: Nx.Tensor.t(),   # Shape: {nnz} - non-zero values
    shape: {pos_integer(), pos_integer()}  # Matrix dimensions
  }
  @type t :: %__MODULE__{
          data: Nx.Tensor.t() | sparse_data() | nil,
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
    # True sparse implementation using COO (Coordinate) format
    if Enum.empty?(edges) do
      # Empty sparse matrix
      %{
        indices: Nx.tensor([], type: :s64) |> Nx.reshape({0, 2}),
        values: Nx.tensor([], type: :f32) |> Nx.reshape({0}),
        shape: {size, size}
      }
    else
      # Extract coordinates and values from edges
      {coordinates, values} =
        edges
        |> Enum.map(fn edge ->
          from_idx = Map.get(node_mapping, edge.from_node_id)
          to_idx = Map.get(node_mapping, edge.to_node_id)
          weight = get_edge_weight(edge)

          if from_idx && to_idx do
            {[from_idx, to_idx], weight}
          else
            nil
          end
        end)
        |> Enum.filter(& &1 != nil)
        |> Enum.unzip()

      # Convert to tensors
      indices_tensor = Nx.tensor(coordinates, type: :s64)
      values_tensor = Nx.tensor(values, type: :f32)

      %{
        indices: indices_tensor,
        values: values_tensor,
        shape: {size, size}
      }
    end
  end

  defp get_edge_weight(edge) do
    # Check for weight property, default to 1
    Map.get(edge.properties, "weight", Map.get(edge.properties, :weight, 1))
  end

  @doc """
  Converts between sparse and dense representations.
  """
  @spec convert(t(), matrix_type()) :: t()
  def convert(%__MODULE__{data: nil} = matrix, target_type) do
    # Empty matrix case
    %{matrix | type: target_type}
  end
  def convert(%__MODULE__{type: current_type} = matrix, target_type) do
    if current_type == target_type do
      matrix
    else
      case {current_type, target_type} do
        {:dense, :sparse} -> dense_to_sparse(matrix)
        {:sparse, :dense} -> sparse_to_dense(matrix)
      end
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
  def multiply(%__MODULE__{type: :sparse} = matrix_a, %__MODULE__{type: :sparse} = matrix_b) do
    # Sparse * Sparse: convert to dense for now (proper sparse multiplication is complex)
    dense_a = sparse_to_dense(matrix_a)
    dense_b = sparse_to_dense(matrix_b)
    result = multiply(dense_a, dense_b)
    dense_to_sparse(result)
  end
  def multiply(%__MODULE__{type: :sparse} = matrix_a, %__MODULE__{type: :dense} = matrix_b) do
    # Sparse * Dense: convert sparse to dense
    dense_a = sparse_to_dense(matrix_a)
    multiply(dense_a, matrix_b)
  end
  def multiply(%__MODULE__{type: :dense} = matrix_a, %__MODULE__{type: :sparse} = matrix_b) do
    # Dense * Sparse: convert sparse to dense
    dense_b = sparse_to_dense(matrix_b)
    multiply(matrix_a, dense_b)
  end
  def multiply(%__MODULE__{data: data_a, node_mapping: mapping_a, type: :dense} = matrix_a,
               %__MODULE__{data: data_b, node_mapping: mapping_b, type: :dense}) do
    # Dense * Dense: standard matrix multiplication
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

  # Conversion functions between sparse and dense formats

  defp dense_to_sparse(%__MODULE__{data: data} = matrix) do
    {rows, cols} = Nx.shape(data)

    # Find non-zero elements
    flat_data = Nx.to_flat_list(data)

    {coordinates, values} =
      flat_data
      |> Enum.with_index()
      |> Enum.filter(fn {value, _idx} -> value != 0 end)
      |> Enum.map(fn {value, idx} ->
        row = div(idx, cols)
        col = rem(idx, cols)
        {[row, col], value}
      end)
      |> Enum.unzip()

    sparse_data = if Enum.empty?(coordinates) do
      %{
        indices: Nx.tensor([], type: :s64) |> Nx.reshape({0, 2}),
        values: Nx.tensor([], type: :f32) |> Nx.reshape({0}),
        shape: {rows, cols}
      }
    else
      %{
        indices: Nx.tensor(coordinates, type: :s64),
        values: Nx.tensor(values, type: :f32),
        shape: {rows, cols}
      }
    end

    %{matrix | data: sparse_data, type: :sparse}
  end

  defp sparse_to_dense(%__MODULE__{data: sparse_data} = matrix) do
    %{indices: indices, values: values, shape: {rows, cols}} = sparse_data

    # Create dense matrix filled with zeros
    dense_data = Nx.broadcast(0.0, {rows, cols})

    # Set non-zero values
    if Nx.size(indices) > 0 do
      indices_list = Nx.to_list(indices)
      values_list = Nx.to_list(values)

      # Build dense matrix by setting each non-zero element
      dense_matrix =
        Enum.zip(indices_list, values_list)
        |> Enum.reduce(dense_data, fn {[row, col], value}, acc ->
          Nx.put_slice(acc, [row, col], Nx.tensor([[value]]))
        end)

      %{matrix | data: dense_matrix, type: :dense}
    else
      # Empty sparse matrix becomes zero dense matrix
      %{matrix | data: dense_data, type: :dense}
    end
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

  def to_edges(%__MODULE__{data: %{indices: indices, values: values}, node_mapping: node_mapping, type: :sparse}) do
    # Sparse matrix case - directly use coordinates and values
    # Create reverse mapping (index -> node_id)
    reverse_mapping =
      node_mapping
      |> Enum.into(%{}, fn {node_id, idx} -> {idx, node_id} end)

    if Nx.size(indices) == 0 do
      []
    else
      indices_list = Nx.to_list(indices)
      values_list = Nx.to_list(values)

      Enum.zip(indices_list, values_list)
      |> Enum.map(fn {[row, col], weight} ->
        from_node = Map.get(reverse_mapping, row)
        to_node = Map.get(reverse_mapping, col)
        {from_node, to_node, weight}
      end)
    end
  end

  def to_edges(%__MODULE__{data: data, node_mapping: node_mapping, type: :dense}) when data != nil do
    # Dense matrix case - scan for non-zero entries
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
