# Matrix Algebra Performance Benchmark
# ===================================
#
# This benchmark tests Semigraph's matrix operations without Mix.install
# to avoid Phoenix dependency conflicts.

# Add the lib path to the Elixir path
Code.prepend_path("../../_build/dev/lib/semigraph/ebin")
Code.prepend_path("../../_build/dev/lib/nx/ebin")

# Try to load additional dependencies that might be needed
for dep <- ["complex", "elixir_make", "telemetry"] do
  Code.prepend_path("../../_build/dev/lib/#{dep}/ebin")
end

# Ensure Semigraph and dependencies are compiled
System.cmd("mix", ["compile"], cd: "../..")

# Start the applications we need
Application.ensure_all_started(:nx)

# Try to check if Complex is available and load it if needed
try do
  Application.ensure_all_started(:complex)
rescue
  _ -> IO.puts("Complex package not available")
end

defmodule MatrixAlgebraBenchmark do
  def format_number(num) when num >= 1_000_000 do
    "#{Float.round(num / 1_000_000, 1)}M"
  end

  def format_number(num) when num >= 1_000 do
    "#{Float.round(num / 1_000, 1)}k"
  end

  def format_number(num), do: "#{num}"

  def format_time(microseconds) do
    cond do
      microseconds >= 1_000_000 -> "#{Float.round(microseconds / 1_000_000, 2)}s"
      microseconds >= 1_000 -> "#{Float.round(microseconds / 1_000, 2)}ms"
      true -> "#{microseconds}μs"
    end
  end

  def memory_info do
    memory = :erlang.memory()
    total_mb = memory[:total] / 1_048_576
    processes_mb = memory[:processes] / 1_048_576
    system_mb = memory[:system] / 1_048_576

    IO.puts("💾 Memory Usage:")
    IO.puts("  Total: #{Float.round(total_mb, 1)} MB")
    IO.puts("  Processes: #{Float.round(processes_mb, 1)} MB")
    IO.puts("  System: #{Float.round(system_mb, 1)} MB")
    IO.puts("")
  end

  def benchmark(name, fun) do
    {time, result} = :timer.tc(fun)
    IO.puts("  #{name}: #{format_time(time)}")
    result
  end

  def benchmark_with_rate(name, count, fun) do
    {time, result} = :timer.tc(fun)
    if time > 0 do
      rate = count / (time / 1_000_000)
      IO.puts("  #{name}: #{format_time(time)} (#{format_number(rate)} ops/sec)")
    else
      IO.puts("  #{name}: #{format_time(time)} (instant)")
    end
    result
  end

  def create_test_graph(name, node_count, edge_count) do
    {:ok, graph} = Semigraph.Graph.new(name)

    # Add nodes
    for i <- 1..node_count do
      node = Semigraph.Node.new("node_#{i}", ["test"], %{id: i})
      {:ok, _} = Semigraph.Graph.add_node(graph, node)
    end

    # Add edges in a pattern that creates interesting matrix structure
    for i <- 1..edge_count do
      from = "node_#{rem(i, node_count) + 1}"
      to = "node_#{rem(i * 2, node_count) + 1}"

      edge = Semigraph.Edge.new("edge_#{i}", from, to, "connects", %{weight: :rand.uniform(100) / 100})
      {:ok, _} = Semigraph.Graph.add_edge(graph, edge)
    end

    graph
  end

  def test_sparse_vs_dense_performance do
    IO.puts("")
    IO.puts("📊 Sparse vs Dense Performance")
    IO.puts("------------------------------")

    try do
      # Create graphs of different densities
      test_cases = [
        {20, 10, "Sparse (20 nodes, 10 edges)"},
        {20, 50, "Medium (20 nodes, 50 edges)"},
        {20, 100, "Dense (20 nodes, 100 edges)"}
      ]

      for {nodes, edges, description} <- test_cases do
        IO.puts("")
        IO.puts("Testing #{description}")

        graph = create_test_graph("test_graph_#{nodes}_#{edges}", nodes, edges)

        # Create matrix and test operations
        {time, {:ok, matrix}} = :timer.tc(fn ->
          Semigraph.Matrix.from_graph(graph, :sparse)
        end)
        IO.puts("  Create matrix: #{format_time(time)}")

        # Test conversion between formats if available
        try do
          {conv_time, dense_matrix} = :timer.tc(fn ->
            Semigraph.Matrix.convert(matrix, :dense)
          end)
          IO.puts("  ✅ Format conversion: #{format_time(conv_time)}")

          try do
            {mult_time, _dense_result} = :timer.tc(fn ->
              Semigraph.Matrix.multiply(dense_matrix, dense_matrix)
            end)
            IO.puts("  ✅ Dense matrix multiply: #{format_time(mult_time)}")
          rescue
            error -> IO.puts("  ❌ Dense matrix multiply: Error - #{Exception.message(error)}")
          end

          try do
            {sparse_time, _sparse_result} = :timer.tc(fn ->
              Semigraph.Matrix.multiply(matrix, matrix)
            end)
            IO.puts("  ✅ Sparse matrix multiply: #{format_time(sparse_time)}")
          rescue
            error -> IO.puts("  ❌ Sparse matrix multiply: Error - #{Exception.message(error)}")
          end

        rescue
          error -> IO.puts("  ❌ Format conversion: Error - #{Exception.message(error)}")
        end
      end

    rescue
      error ->
        IO.puts("  Sparse/Dense comparison: Error - #{Exception.message(error)}")
    end
  end

  def test_matrix_scaling do
    IO.puts("")
    IO.puts("📈 Matrix Scaling Performance")
    IO.puts("-----------------------------")

    try do
      scaling_tests = [
        {10, 15, "Tiny"},
        {50, 100, "Small"},
        {100, 200, "Medium"}
      ]

      for {nodes, edges, size} <- scaling_tests do
        IO.puts("")
        IO.puts("#{size} Graph (#{nodes} nodes, #{edges} edges)")

        graph = create_test_graph("scaling_#{size}_#{nodes}_#{edges}", nodes, edges)

        {time, {:ok, matrix}} = :timer.tc(fn ->
          Semigraph.Matrix.from_graph(graph, :sparse)
        end)
        IO.puts("  Create #{String.downcase(size)} matrix: #{format_time(time)}")

        try do
          {mult_time, _result} = :timer.tc(fn ->
            Semigraph.Matrix.multiply(matrix, matrix)
          end)
          IO.puts("  ✅ #{size} matrix multiply: #{format_time(mult_time)}")
        rescue
          error -> IO.puts("  ❌ #{size} matrix multiply: Error - #{Exception.message(error)}")
        end

        # Test matrix power operations if available
        try do
          {power_time, _power_result} = :timer.tc(fn ->
            Semigraph.Matrix.power(matrix, 2)
          end)
          IO.puts("  ✅ #{size} matrix power: #{format_time(power_time)}")
        rescue
          error -> IO.puts("  ❌ Matrix power: Error - #{Exception.message(error)}")
        end
      end

    rescue
      error ->
        IO.puts("  Matrix scaling: Error - #{Exception.message(error)}")
    end
  end

  def run do
    IO.puts("🧮 Matrix Algebra Performance Benchmark")
    IO.puts("=======================================")
    IO.puts("")
    memory_info()

    try do
      # Test basic matrix operations
      IO.puts("🔢 Matrix Operations")
      IO.puts("--------------------")
      graph = create_test_graph("test_graph", 10, 15)
      {time, {:ok, _matrix}} = :timer.tc(fn ->
        Semigraph.Matrix.from_graph(graph, :sparse)
      end)
      IO.puts("  Create matrix from graph: #{format_time(time)}")
      IO.puts("  Matrix operations: SUCCESS")

      test_sparse_vs_dense_performance()
      test_matrix_scaling()

      IO.puts("")
      IO.puts("✅ Matrix Algebra Benchmark Complete!")
      memory_info()

    rescue
      error ->
        IO.puts("❌ Error during matrix benchmark: #{inspect(error)}")
        IO.puts("Error type: #{error.__struct__}")
        IO.puts("Message: #{Exception.message(error)}")

        IO.puts("")
        IO.puts("🔍 Checking available modules:")

        # Check what matrix-related modules are available
        available_modules = :code.all_loaded()
        |> Enum.filter(fn {module, _} ->
          module_str = Atom.to_string(module)
          String.contains?(module_str, "Matrix") or String.contains?(module_str, "Semiring")
        end)
        |> Enum.map(fn {module, _} -> module end)

        if length(available_modules) > 0 do
          IO.puts("Available matrix modules:")
          for module <- available_modules do
            IO.puts("  - #{module}")
          end
        else
          IO.puts("No matrix modules found. Matrix functionality may not be compiled.")
        end
    end
  end
end

MatrixAlgebraBenchmark.run()
