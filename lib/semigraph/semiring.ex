defmodule Semigraph.Semiring do
  @moduledoc """
  Semiring algebra kernels for specialized graph operations.

  Semirings provide algebraic structures for graph algorithms like shortest paths,
  reachability, counting paths, and custom scoring functions.
  """

  @type operation :: (term(), term() -> term())

  @type t :: %__MODULE__{
          name: String.t(),
          zero: term(),
          one: term(),
          plus: operation(),
          times: operation()
        }

  defstruct [:name, :zero, :one, :plus, :times]

  @doc """
  Boolean semiring for reachability queries.
  """
  @spec boolean() :: t()
  def boolean do
    %__MODULE__{
      name: "Boolean",
      zero: false,
      one: true,
      plus: &(&1 or &2),
      times: &(&1 and &2)
    }
  end

  @doc """
  Tropical semiring for shortest path calculations.
  """
  @spec tropical() :: t()
  def tropical do
    %__MODULE__{
      name: "Tropical",
      zero: :infinity,
      one: 0,
      plus: &min/2,
      times: fn
        :infinity, _ -> :infinity
        _, :infinity -> :infinity
        a, b -> a + b
      end
    }
  end

  @doc """
  Counting semiring for path enumeration.
  """
  @spec counting() :: t()
  def counting do
    %__MODULE__{
      name: "Counting",
      zero: 0,
      one: 1,
      plus: &(&1 + &2),
      times: &(&1 * &2)
    }
  end

  @doc """
  Probability semiring for probabilistic reasoning.
  """
  @spec probability() :: t()
  def probability do
    %__MODULE__{
      name: "Probability",
      zero: 0.0,
      one: 1.0,
      plus: fn a, b -> a + b - a * b end,
      times: &(&1 * &2)
    }
  end

  @doc """
  Creates a custom semiring with user-defined operations.
  """
  @spec custom(String.t(), term(), term(), operation(), operation()) :: t()
  def custom(name, zero, one, plus_op, times_op) do
    %__MODULE__{
      name: name,
      zero: zero,
      one: one,
      plus: plus_op,
      times: times_op
    }
  end

  @doc """
  Applies semiring addition operation.
  """
  @spec add(t(), term(), term()) :: term()
  def add(%__MODULE__{plus: plus_op}, a, b) do
    plus_op.(a, b)
  end

  @doc """
  Applies semiring multiplication operation.
  """
  @spec multiply(t(), term(), term()) :: term()
  def multiply(%__MODULE__{times: times_op}, a, b) do
    times_op.(a, b)
  end

  @doc """
  Matrix multiplication using the semiring operations.
  """
  @spec matrix_multiply(t(), Nx.Tensor.t(), Nx.Tensor.t()) :: Nx.Tensor.t()
  def matrix_multiply(semiring, matrix_a, matrix_b) do
    case semiring.name do
      "Boolean" ->
        # Use Nx boolean operations for efficiency
        boolean_matrix_multiply(matrix_a, matrix_b)

      "Tropical" ->
        # Min-plus semiring
        tropical_matrix_multiply(matrix_a, matrix_b)

      "Counting" ->
        # Standard arithmetic matrix multiplication
        Nx.dot(matrix_a, matrix_b)

      "Probability" ->
        # Custom probability semiring multiplication
        probability_matrix_multiply(semiring, matrix_a, matrix_b)

      _ ->
        # Generic semiring multiplication (slower but works for custom semirings)
        generic_matrix_multiply(semiring, matrix_a, matrix_b)
    end
  end

  @doc """
  Validates semiring properties (associativity, distributivity, etc.).
  """
  @spec validate(t(), [term()]) :: boolean()
  def validate(_semiring, _test_values \\ [0, 1, 2]) do
    # TODO: Property-based testing of semiring axioms
    :not_implemented
  end

  # Private helper functions for optimized matrix operations

  defp boolean_matrix_multiply(matrix_a, matrix_b) do
    # For boolean semiring: (A ⊗ B)[i,j] = OR_k(A[i,k] AND B[k,j])
    {_m, k1} = Nx.shape(matrix_a)
    {k2, _n} = Nx.shape(matrix_b)

    if k1 != k2 do
      raise ArgumentError, "incompatible matrix dimensions for multiplication"
    end

    # Expand dimensions for broadcasting
    a_expanded = Nx.new_axis(matrix_a, 2)  # Shape: {m, k, 1}
    b_expanded = Nx.new_axis(matrix_b, 0)  # Shape: {1, k, n}

    # Element-wise AND, then OR along the k dimension
    pairwise_and = Nx.logical_and(a_expanded, b_expanded)  # Shape: {m, k, n}
    Nx.any(pairwise_and, axes: [1])  # Shape: {m, n}
  end

  defp tropical_matrix_multiply(matrix_a, matrix_b) do
    # For tropical semiring: (A ⊗ B)[i,j] = min_k(A[i,k] + B[k,j])
    {_m, k1} = Nx.shape(matrix_a)
    {k2, _n} = Nx.shape(matrix_b)

    if k1 != k2 do
      raise ArgumentError, "incompatible matrix dimensions for multiplication"
    end

    # Handle infinity values by replacing with large numbers for computation
    a_clean = replace_infinity(matrix_a)
    b_clean = replace_infinity(matrix_b)

    # Broadcast and compute all pairwise sums, then take minimum
    a_expanded = Nx.new_axis(a_clean, 2)  # Shape: {m, k, 1}
    b_expanded = Nx.new_axis(b_clean, 0)  # Shape: {1, k, n}

    pairwise_sums = Nx.add(a_expanded, b_expanded)  # Shape: {m, k, n}
    result = Nx.reduce_min(pairwise_sums, axes: [1])  # Shape: {m, n}

    # Convert back large numbers to infinity
    restore_infinity(result)
  end

  defp probability_matrix_multiply(semiring, matrix_a, matrix_b) do
    # Use generic multiplication for probability semiring
    generic_matrix_multiply(semiring, matrix_a, matrix_b)
  end

  defp generic_matrix_multiply(semiring, matrix_a, matrix_b) do
    # Generic but slower implementation for custom semirings
    {m, k1} = Nx.shape(matrix_a)
    {k2, n} = Nx.shape(matrix_b)

    if k1 != k2 do
      raise ArgumentError, "incompatible matrix dimensions for multiplication"
    end

    # Convert to nested lists for easier manipulation
    a_list = Nx.to_list(matrix_a)
    b_list = Nx.to_list(matrix_b)

    result =
      for i <- 0..(m-1) do
        for j <- 0..(n-1) do
          # Compute dot product with semiring operations
          row_i = Enum.at(a_list, i)
          col_j = for k <- 0..(k1-1), do: Enum.at(Enum.at(b_list, k), j)

          # Semiring matrix multiplication: sum of products becomes
          # semiring_add of semiring_multiply
          pairs = Enum.zip(row_i, col_j)

          Enum.reduce(pairs, semiring.zero, fn {a, b}, acc ->
            product = semiring.times.(a, b)
            semiring.plus.(acc, product)
          end)
        end
      end

    Nx.tensor(result)
  end

  defp replace_infinity(tensor) do
    # Replace :infinity with a large number for computation
    large_number = 1.0e10

    tensor
    |> Nx.to_flat_list()
    |> Enum.map(fn
      :infinity -> large_number
      val -> val
    end)
    |> Nx.tensor()
    |> Nx.reshape(Nx.shape(tensor))
  end

  defp restore_infinity(tensor) do
    # Convert large numbers back to :infinity
    large_number = 1.0e10
    threshold = large_number * 0.9  # Allow for some numerical error

    tensor
    |> Nx.to_flat_list()
    |> Enum.map(fn
      val when val > threshold -> :infinity
      val -> val
    end)
    |> Nx.tensor()
    |> Nx.reshape(Nx.shape(tensor))
  end
end
