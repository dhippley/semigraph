# Direct Semigraph Benchmark (No Mix.install)
# This benchmark uses the compiled Semigraph modules directly

# Add the lib path to the Elixir path
Code.prepend_path("../../_build/dev/lib/semigraph/ebin")

# Ensure Semigraph is compiled
System.cmd("mix", ["compile"], cd: "../..")

# Now we can use Semigraph modules directly
defmodule DirectBenchmark do
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

  def run do
    IO.puts("Starting Direct Semigraph Benchmark...")
    IO.puts("")
    memory_info()

    IO.puts("🚀 Semigraph Performance Test")
    IO.puts("==============================")
    IO.puts("")

    try do
      # Test basic graph operations
      IO.puts("📊 Basic Graph Operations")
      IO.puts("--------------------------")

      {:ok, graph} = benchmark("Create new graph", fn ->
        Semigraph.Graph.new("test_graph")
      end)

      # Add nodes
      node_count = 1000
      benchmark_with_rate("Add #{format_number(node_count)} nodes", node_count, fn ->
        for i <- 1..node_count do
          node = Semigraph.Node.new("node_#{i}", ["test"], %{id: i, type: "test"})
          {:ok, _} = Semigraph.Graph.add_node(graph, node)
        end
      end)

      # Add edges
      edge_count = 500
      benchmark_with_rate("Add #{format_number(edge_count)} edges", edge_count, fn ->
        for i <- 1..edge_count do
          from = "node_#{i}"
          to = "node_#{rem(i, node_count) + 1}"
          edge = Semigraph.Edge.new("edge_#{i}", from, to, "connects", %{weight: i})
          {:ok, _} = Semigraph.Graph.add_edge(graph, edge)
        end
      end)

      # Query operations
      IO.puts("")
      IO.puts("🔍 Query Operations")
      IO.puts("-------------------")

      benchmark("List all nodes", fn ->
        Semigraph.Graph.list_nodes(graph)
      end)

      benchmark("List all edges", fn ->
        Semigraph.Graph.list_edges(graph)
      end)

      benchmark("Get single node", fn ->
        {:ok, _node} = Semigraph.Graph.get_node(graph, "node_100")
      end)

      # Check if these methods exist
      benchmark("Get outgoing edges", fn ->
        Semigraph.Graph.get_outgoing_edges(graph, "node_100")
      end)

      benchmark("Get incoming edges", fn ->
        Semigraph.Graph.get_incoming_edges(graph, "node_100")
      end)

      IO.puts("")
      IO.puts("✅ Direct Benchmark Complete!")
      memory_info()

    rescue
      error ->
        IO.puts("❌ Error during benchmark: #{inspect(error)}")
        IO.puts("Error type: #{error.__struct__}")
        IO.puts("Message: #{Exception.message(error)}")
        IO.puts("Stacktrace:")
        IO.puts(Exception.format_stacktrace(__STACKTRACE__))
        IO.puts("This might indicate that Semigraph modules are not available or compiled.")
        IO.puts("Try running 'mix compile' in the project root first.")
    end
  end
end

DirectBenchmark.run()
