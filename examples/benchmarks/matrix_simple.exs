#!/usr/bin/env elixir

Mix.install([
  {:semigraph, path: Path.join(__DIR__, "../..")},
  {:nx, "~> 0.7"}
])

# Simplified Matrix Operations Performance Benchmark
# =================================================
#
# This benchmark evaluates the performance of Semigraph's matrix operations
# using the actual available API methods.

defmodule SimpleMatrixBenchmark do
  alias Semigraph.{Graph, Matrix, Semiring, Node, Edge}
  require Logger

  def run do
    IO.puts("Simple Matrix Operations Performance Benchmark")
    IO.puts("=" <> String.duplicate("=", 60))
    IO.puts("")

    # Test different graph sizes
    sizes = [10, 25, 50, 100]

    Enum.each(sizes, fn size ->
      IO.puts("Testing #{size}x#{size} matrices...")
      benchmark_size(size)
      IO.puts("")
    end)

    IO.puts("Matrix conversion benchmarks...")
    benchmark_conversions()

    IO.puts("\nSemiring operations benchmarks...")
    benchmark_semirings()

    IO.puts("\nSimple Matrix Benchmark Complete!")
  end

  defp benchmark_size(size) do
    # Create a test graph
    {:ok, graph} = Graph.new("test_graph_#{size}")

    # Add nodes
    graph = add_test_nodes(graph, size)
    nodes = Graph.list_nodes(graph)
    IO.puts("  Added #{length(nodes)} nodes")

    # Add edges (create a connected graph)
    graph = add_test_edges(graph, size)

    # Debug: Check if we have edges
    edges = Graph.list_edges(graph)
    IO.puts("  Graph has #{length(edges)} edges")
    
    if length(edges) == 0 do
      IO.puts("  ⚠️  No edges found, skipping matrix operations for size #{size}")
    else
      proceed_with_benchmarks(graph, size)
    end
  end

  defp proceed_with_benchmarks(graph, _size) do
    # Convert to matrices
    {dense_time, dense_result} = :timer.tc(fn ->
      Matrix.from_graph(graph, :dense)
    end)
    
    case dense_result do
      {:ok, dense_matrix} -> 
        IO.puts("  Dense matrix creation: #{format_time(dense_time)}")
        
        {sparse_time, sparse_result} = :timer.tc(fn ->
          Matrix.from_graph(graph, :sparse)
        end)
        
        case sparse_result do
          {:ok, sparse_matrix} -> 
            IO.puts("  Sparse matrix creation: #{format_time(sparse_time)}")
            # Matrix operations
            benchmark_matrix_operations(dense_matrix, sparse_matrix)
          {:error, error} -> 
            IO.puts("  ⚠️  Sparse matrix creation failed: #{inspect(error)}")
            # Just benchmark dense operations
            benchmark_dense_operations(dense_matrix)
        end
      {:error, error} -> 
        IO.puts("  ⚠️  Dense matrix creation failed: #{inspect(error)}")
    end
  end

  defp benchmark_dense_operations(dense_matrix) do
    # Matrix multiplication
    {time, _result} = :timer.tc(fn ->
      Matrix.multiply(dense_matrix, dense_matrix)
    end)
    IO.puts("  Dense matrix multiplication: #{format_time(time)}")

    # Matrix power
    {time, _result} = :timer.tc(fn ->
      Matrix.power(dense_matrix, 2)
    end)
    IO.puts("  Dense matrix power: #{format_time(time)}")

    # Matrix transpose
    {time, _result} = :timer.tc(fn ->
      Matrix.transpose(dense_matrix)
    end)
    IO.puts("  Dense matrix transpose: #{format_time(time)}")
  end

  defp add_test_nodes(graph, size) do
    Enum.reduce(1..size, graph, fn i, acc ->
      node = Node.new("node_#{i}", [], %{id: i, value: i * 10})
      {:ok, updated_graph} = Graph.add_node(acc, node)
      updated_graph
    end)
  end

  defp add_test_edges(graph, size) when size > 1 do
    # Create a simple ring topology to ensure connectivity
    Enum.reduce(1..(size-1), graph, fn i, acc ->
      from = "node_#{i}"
      to = "node_#{i + 1}"
      
      edge = Edge.new(from, to, "CONNECTS", %{weight: 1.0})
      case Graph.add_edge(acc, edge) do
        {:ok, updated_graph} -> updated_graph
        {:error, reason} -> 
          IO.puts("  Debug: Failed to add edge #{from} -> #{to}: #{inspect(reason)}")
          acc
      end
    end)
    |> then(fn graph_with_edges ->
      # Close the ring
      if size > 2 do
        edge = Edge.new("node_#{size}", "node_1", "CONNECTS", %{weight: 1.0})
        case Graph.add_edge(graph_with_edges, edge) do
          {:ok, updated_graph} -> updated_graph
          {:error, reason} -> 
            IO.puts("  Debug: Failed to add closing edge: #{inspect(reason)}")
            graph_with_edges
        end
      else
        graph_with_edges
      end
    end)
  end

  defp add_test_edges(graph, _size), do: graph

  defp benchmark_matrix_operations(dense_matrix, sparse_matrix) do
    # Matrix multiplication
    {time, _result} = :timer.tc(fn ->
      Matrix.multiply(dense_matrix, dense_matrix)
    end)
    IO.puts("  Dense matrix multiplication: #{format_time(time)}")

    {time, _result} = :timer.tc(fn ->
      Matrix.multiply(sparse_matrix, sparse_matrix)
    end)
    IO.puts("  Sparse matrix multiplication: #{format_time(time)}")

    # Matrix power
    {time, _result} = :timer.tc(fn ->
      Matrix.power(dense_matrix, 2)
    end)
    IO.puts("  Dense matrix power: #{format_time(time)}")

    {time, _result} = :timer.tc(fn ->
      Matrix.power(sparse_matrix, 2)
    end)
    IO.puts("  Sparse matrix power: #{format_time(time)}")

    # Matrix transpose
    {time, _result} = :timer.tc(fn ->
      Matrix.transpose(dense_matrix)
    end)
    IO.puts("  Dense matrix transpose: #{format_time(time)}")

    {time, _result} = :timer.tc(fn ->
      Matrix.transpose(sparse_matrix)
    end)
    IO.puts("  Sparse matrix transpose: #{format_time(time)}")

    # Elementwise operations
    addition_op = fn a, b -> a + b end
    {time, _result} = :timer.tc(fn ->
      Matrix.elementwise_op(dense_matrix, dense_matrix, addition_op)
    end)
    IO.puts("  Dense matrix addition: #{format_time(time)}")

    {time, _result} = :timer.tc(fn ->
      Matrix.elementwise_op(sparse_matrix, sparse_matrix, addition_op)
    end)
    IO.puts("  Sparse matrix addition: #{format_time(time)}")
  end

  defp benchmark_conversions do
    {:ok, graph} = Graph.new("conversion_test")
    graph = add_test_nodes(graph, 50)
    graph = add_test_edges(graph, 50)

    {:ok, dense_matrix} = Matrix.from_graph(graph, :dense)
    {:ok, sparse_matrix} = Matrix.from_graph(graph, :sparse)

    # Dense to sparse conversion
    {time, _result} = :timer.tc(fn ->
      Matrix.convert(dense_matrix, :sparse)
    end)
    IO.puts("  Dense to sparse conversion: #{format_time(time)}")

    # Sparse to dense conversion
    {time, _result} = :timer.tc(fn ->
      Matrix.convert(sparse_matrix, :dense)
    end)
    IO.puts("  Sparse to dense conversion: #{format_time(time)}")
  end

  defp benchmark_semirings do
    {:ok, graph} = Graph.new("semiring_test")
    graph = add_test_nodes(graph, 30)
    graph = add_test_edges(graph, 30)

    {:ok, matrix1} = Matrix.from_graph(graph, :dense)
    {:ok, matrix2} = Matrix.from_graph(graph, :dense)

    # Test different semirings
    semirings = [
      {"Boolean", Semiring.boolean()},
      {"Tropical", Semiring.tropical()},
      {"Counting", Semiring.counting()},
      {"Probability", Semiring.probability()}
    ]

    Enum.each(semirings, fn {name, semiring} ->
      {time, _result} = :timer.tc(fn ->
        Semiring.matrix_multiply(semiring, matrix1, matrix2)
      end)
      IO.puts("  #{name} semiring multiply: #{format_time(time)}")
    end)

    # Test custom semiring
    custom_semiring = Semiring.custom("max_plus", 0, 1, &max/2, &+/2)
    {time, _result} = :timer.tc(fn ->
      Semiring.matrix_multiply(custom_semiring, matrix1, matrix2)
    end)
    IO.puts("  Custom (max-plus) semiring: #{format_time(time)}")
  end

  defp format_time(microseconds) when microseconds < 1000 do
    "#{microseconds}μs"
  end

  defp format_time(microseconds) when microseconds < 1_000_000 do
    "#{Float.round(microseconds / 1000, 2)}ms"
  end

  defp format_time(microseconds) do
    "#{Float.round(microseconds / 1_000_000, 2)}s"
  end
end

# Run the benchmark
SimpleMatrixBenchmark.run()
