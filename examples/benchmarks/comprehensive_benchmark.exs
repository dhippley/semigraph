# Comprehensive Semigraph Benchmark
# Advanced performance testing without Mix.install

# Add the lib path to the Elixir path
Code.prepend_path("../../_build/dev/lib/semigraph/ebin")

# Ensure Semigraph is compiled
System.cmd("mix", ["compile"], cd: "../..")

defmodule ComprehensiveBenchmark do
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
      node = Semigraph.Node.new("node_#{i}", ["person"], %{
        id: i,
        name: "Person #{i}",
        age: rem(i, 80) + 18,
        city: Enum.at(["NYC", "SF", "LA", "Chicago", "Boston"], rem(i, 5))
      })
      {:ok, _} = Semigraph.Graph.add_node(graph, node)
    end

    # Add edges with various relationship types
    edge_types = ["KNOWS", "WORKS_WITH", "FRIENDS", "FOLLOWS", "COLLABORATES"]
    for i <- 1..edge_count do
      from = "node_#{i}"
      to = "node_#{rem(i, node_count) + 1}"
      rel_type = Enum.at(edge_types, rem(i, length(edge_types)))

      edge = Semigraph.Edge.new("edge_#{i}", from, to, rel_type, %{
        weight: :rand.uniform(100) / 100,
        since: 2020 + rem(i, 4)
      })
      {:ok, _} = Semigraph.Graph.add_edge(graph, edge)
    end

    graph
  end

  def run do
    IO.puts("🚀 Comprehensive Semigraph Benchmark")
    IO.puts("====================================")
    IO.puts("")
    memory_info()

    try do
      # Test different graph sizes
      test_scenarios = [
        {100, 50, "Small"},
        {1000, 500, "Medium"},
        {5000, 2000, "Large"}
      ]

      for {node_count, edge_count, size_label} <- test_scenarios do
        IO.puts("📊 #{size_label} Graph (#{node_count} nodes, #{edge_count} edges)")
        IO.puts(String.duplicate("-", 50))

        graph = benchmark("Create #{String.downcase(size_label)} graph", fn ->
          create_test_graph("#{String.downcase(size_label)}_graph", node_count, edge_count)
        end)

        # Basic operations
        benchmark("List all nodes", fn ->
          Semigraph.Graph.list_nodes(graph)
        end)

        benchmark("List all edges", fn ->
          Semigraph.Graph.list_edges(graph)
        end)

        # Query performance
        sample_nodes = ["node_10", "node_50", "node_100", "node_#{div(node_count, 2)}"]

        benchmark_with_rate("Random node lookups", length(sample_nodes), fn ->
          for node_id <- sample_nodes do
            {:ok, _} = Semigraph.Graph.get_node(graph, node_id)
          end
        end)

        benchmark_with_rate("Get outgoing edges", length(sample_nodes), fn ->
          for node_id <- sample_nodes do
            Semigraph.Graph.get_outgoing_edges(graph, node_id)
          end
        end)

        benchmark_with_rate("Get incoming edges", length(sample_nodes), fn ->
          for node_id <- sample_nodes do
            Semigraph.Graph.get_incoming_edges(graph, node_id)
          end
        end)

        # Filtered queries
        benchmark("Filter nodes by label", fn ->
          Semigraph.Graph.list_nodes(graph, label: "person")
        end)

        benchmark("Filter nodes by property", fn ->
          Semigraph.Graph.list_nodes(graph, property: {"city", "NYC"})
        end)

        benchmark("Filter edges by type", fn ->
          Semigraph.Graph.list_edges(graph, type: "KNOWS")
        end)

        IO.puts("")
        memory_info()
      end

      # Stress test with concurrent operations
      IO.puts("⚡ Concurrent Operations Test")
      IO.puts("-----------------------------")

      {:ok, stress_graph} = Semigraph.Graph.new("stress_test")

      # Pre-populate with some data
      for i <- 1..100 do
        node = Semigraph.Node.new("stress_node_#{i}", ["test"], %{id: i})
        {:ok, _} = Semigraph.Graph.add_node(stress_graph, node)
      end

      benchmark("100 concurrent reads", fn ->
        tasks = for i <- 1..100 do
          Task.async(fn ->
            {:ok, _} = Semigraph.Graph.get_node(stress_graph, "stress_node_#{rem(i, 100) + 1}")
          end)
        end
        Task.await_many(tasks)
      end)

      benchmark("Mixed concurrent operations", fn ->
        tasks = for i <- 1..50 do
          Task.async(fn ->
            case rem(i, 3) do
              0 -> Semigraph.Graph.list_nodes(stress_graph)
              1 -> {:ok, _} = Semigraph.Graph.get_node(stress_graph, "stress_node_#{rem(i, 100) + 1}")
              2 -> Semigraph.Graph.get_outgoing_edges(stress_graph, "stress_node_#{rem(i, 100) + 1}")
            end
          end)
        end
        Task.await_many(tasks)
      end)

      IO.puts("")
      IO.puts("✅ Comprehensive Benchmark Complete!")
      memory_info()

    rescue
      error ->
        IO.puts("❌ Error during benchmark: #{inspect(error)}")
        IO.puts("Error type: #{error.__struct__}")
        IO.puts("Message: #{Exception.message(error)}")
        IO.puts("Stacktrace:")
        IO.puts(Exception.format_stacktrace(__STACKTRACE__))
    end
  end
end

ComprehensiveBenchmark.run()
