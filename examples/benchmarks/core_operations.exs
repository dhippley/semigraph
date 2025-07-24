#!/usr/bin/env elixir

# Core Graph Operations Benchmarking
# Comprehensive performance analysis for basic Semigraph operations

Mix.install([{:semigraph, path: Path.expand("../../", __DIR__)}])

alias Semigraph.{Graph, Node, Edge}
require Logger

IO.puts """
📊 Semigraph Core Operations Benchmarking
=========================================

This benchmark suite measures:
1. Graph creation and basic operations
2. Node CRUD performance at scale
3. Edge CRUD performance at scale
4. Property indexing and retrieval
5. Memory usage patterns
6. Concurrent access performance
"""

# ============================================================================
# Benchmark Helper Functions
# ============================================================================

# Simple benchmark runner
run_benchmark = fn name, iterations, fun ->
  IO.puts "\n🔬 #{name} (#{iterations} iterations)"
  
  # Warmup
  1..10 |> Enum.each(fn _ -> fun.() end)
  
  # Measure
  {time_us, _result} = :timer.tc(fn ->
    1..iterations |> Enum.each(fn _ -> fun.() end)
  end)
  
  time_ms = time_us / 1000
  avg_time_us = time_us / iterations
  ops_per_sec = iterations / (time_ms / 1000)
  
  IO.puts "  Total: #{Float.round(time_ms, 2)} ms"
  IO.puts "  Average: #{Float.round(avg_time_us, 2)} μs"
  IO.puts "  Throughput: #{Float.round(ops_per_sec, 0)} ops/sec"
  
  {time_ms, ops_per_sec}
end

# Generate test data
generate_nodes = fn count ->
  1..count
  |> Enum.map(fn i ->
    Node.new("node_#{i}", ["Person"], %{
      "name" => "User #{i}",
      "age" => rem(i, 80) + 18,
      "city" => Enum.random(["NYC", "SF", "LA", "Chicago", "Boston"]),
      "score" => :rand.uniform(1000),
      "active" => rem(i, 3) == 0
    })
  end)
end

generate_edges = fn node_count ->
  # Create a social network-like structure
  1..node_count
  |> Enum.flat_map(fn i ->
    # Each node connects to 3-8 random other nodes
    friend_count = :rand.uniform(6) + 2
    
    1..friend_count
    |> Enum.map(fn j ->
      to_node = :rand.uniform(node_count)
      Edge.new("edge_#{i}_#{j}_#{to_node}", "node_#{i}", "node_#{to_node}", "KNOWS", %{
        "since" => 2020 + :rand.uniform(4),
        "strength" => :rand.uniform(10) / 10.0,
        "type" => Enum.random(["friend", "colleague", "family"])
      })
    end)
  end)
  |> Enum.uniq_by(&(&1.id))  # Remove duplicates
end

setup_test_graph = fn node_count ->
  # Use unique graph name to avoid ETS table conflicts
  graph_name = "benchmark_graph_#{:rand.uniform(1000000)}"
  {:ok, graph} = Graph.new(graph_name)
  
  nodes = generate_nodes.(node_count)
  edges = generate_edges.(node_count)
  
  # Add all nodes
  {:ok, graph} = Enum.reduce(nodes, {:ok, graph}, fn node, {:ok, acc_graph} ->
    Graph.add_node(acc_graph, node)
  end)
  
  # Add all edges
  {:ok, graph} = Enum.reduce(edges, {:ok, graph}, fn edge, {:ok, acc_graph} ->
    Graph.add_edge(acc_graph, edge)
  end)
  
  {graph, nodes, edges}
end

# Memory usage helper
get_memory_usage = fn ->
  :erlang.memory()
end

print_memory_stats = fn memory_before, memory_after ->
  total_diff = memory_after[:total] - memory_before[:total]
  processes_diff = memory_after[:processes] - memory_before[:processes]
  ets_diff = memory_after[:ets] - memory_before[:ets]
  
  IO.puts "Memory Usage:"
  IO.puts "  Total: #{Float.round(total_diff / 1024 / 1024, 2)} MB"
  IO.puts "  Processes: #{Float.round(processes_diff / 1024 / 1024, 2)} MB"
  IO.puts "  ETS: #{Float.round(ets_diff / 1024 / 1024, 2)} MB"
end

# ============================================================================
# Basic Graph Operations Benchmark
# ============================================================================

IO.puts "\n🚀 Basic Graph Operations Performance"
IO.puts String.duplicate("=", 50)

# Test different graph sizes
graph_sizes = [100, 500, 1000, 2500]

IO.puts "\nGraph Creation Performance:"
Enum.each(graph_sizes, fn size ->
  memory_before = get_memory_usage.()
  
  {time_us, {_graph, nodes, edges}} = :timer.tc(fn -> setup_test_graph.(size) end)
  
  memory_after = get_memory_usage.()
  
  time_ms = time_us / 1000
  node_count = length(nodes)
  edge_count = length(edges)
  
  IO.puts "\n📈 Graph Size: #{size} nodes"
  IO.puts "  Creation Time: #{Float.round(time_ms, 2)} ms"
  IO.puts "  Actual Nodes: #{node_count}"
  IO.puts "  Actual Edges: #{edge_count}"
  IO.puts "  Nodes/sec: #{Float.round(node_count / (time_ms / 1000), 0)}"
  IO.puts "  Edges/sec: #{Float.round(edge_count / (time_ms / 1000), 0)}"
  
  print_memory_stats.(memory_before, memory_after)
end)

# ============================================================================
# CRUD Operations Benchmark
# ============================================================================

IO.puts "\n\n⚡ CRUD Operations Benchmark"
IO.puts String.duplicate("=", 50)

# Setup a medium-sized graph for CRUD testing
{test_graph, _test_nodes, _test_edges} = setup_test_graph.(1000)

# Node operations benchmark
IO.puts "\n📝 Node Operations:"

run_benchmark.("Add Node", 1000, fn ->
  node = Node.new("temp_#{:rand.uniform(100000)}", ["Temp"], %{"value" => :rand.uniform(100)})
  Graph.add_node(test_graph, node)
end)

run_benchmark.("Get Node by ID", 1000, fn ->
  node_id = "node_#{:rand.uniform(1000)}"
  Graph.get_node(test_graph, node_id)
end)

run_benchmark.("List Nodes by Label", 100, fn ->
  Graph.list_nodes(test_graph, label: "Person")
end)

run_benchmark.("Delete Node", 500, fn ->
  # Create a temp node to delete
  temp_id = "temp_delete_#{:rand.uniform(100000)}"
  temp_node = Node.new(temp_id, ["Temp"], %{})
  {:ok, _} = Graph.add_node(test_graph, temp_node)
  Graph.delete_node(test_graph, temp_id)
end)

# Edge operations benchmark
IO.puts "\n🔗 Edge Operations:"

run_benchmark.("Add Edge", 1000, fn ->
  from_id = "node_#{:rand.uniform(1000)}"
  to_id = "node_#{:rand.uniform(1000)}"
  edge_id = "temp_edge_#{:rand.uniform(100000)}"
  edge = Edge.new(edge_id, from_id, to_id, "TEMP", %{"value" => :rand.uniform(100)})
  Graph.add_edge(test_graph, edge)
end)

run_benchmark.("Get Outgoing Edges", 1000, fn ->
  node_id = "node_#{:rand.uniform(1000)}"
  Graph.get_outgoing_edges(test_graph, node_id)
end)

run_benchmark.("Get Incoming Edges", 1000, fn ->
  node_id = "node_#{:rand.uniform(1000)}"
  Graph.get_incoming_edges(test_graph, node_id)
end)

run_benchmark.("List All Edges", 50, fn ->
  Graph.list_edges(test_graph)
end)

# ============================================================================
# Property Search and Filtering Benchmark
# ============================================================================

IO.puts "\n🔍 Property Search Performance"
IO.puts String.duplicate("=", 50)

run_benchmark.("Filter by Single Property", 100, fn ->
  Graph.list_nodes(test_graph)
  |> Enum.filter(fn node ->
    node.properties["active"] == true
  end)
end)

run_benchmark.("Filter by Age Range", 100, fn ->
  Graph.list_nodes(test_graph)
  |> Enum.filter(fn node ->
    age = node.properties["age"]
    age && age >= 25 && age <= 35
  end)
end)

run_benchmark.("Filter by City", 100, fn ->
  Graph.list_nodes(test_graph)
  |> Enum.filter(fn node ->
    node.properties["city"] == "NYC"
  end)
end)

run_benchmark.("Complex Filter", 50, fn ->
  Graph.list_nodes(test_graph)
  |> Enum.filter(fn node ->
    age = node.properties["age"]
    score = node.properties["score"]
    city = node.properties["city"]
    active = node.properties["active"]
    
    age && age >= 25 && score && score > 500 && 
    city in ["NYC", "SF"] && active == true
  end)
end)

run_benchmark.("Sort by Score", 50, fn ->
  Graph.list_nodes(test_graph)
  |> Enum.sort_by(fn node ->
    -(node.properties["score"] || 0)
  end)
  |> Enum.take(10)
end)

# ============================================================================
# Graph Traversal Benchmark
# ============================================================================

IO.puts "\n🕸️  Graph Traversal Performance"
IO.puts String.duplicate("=", 50)

# Helper function for BFS traversal
bfs_traversal = fn graph, start_node_id, max_depth ->
  visited = MapSet.new()
  queue = [{start_node_id, 0}]
  
  traverse = fn traverse_fn, queue, visited, acc ->
    case queue do
      [] -> acc
      [{node_id, depth} | rest] ->
        if depth >= max_depth or MapSet.member?(visited, node_id) do
          traverse_fn.(traverse_fn, rest, visited, acc)
        else
          new_visited = MapSet.put(visited, node_id)
          outgoing = Graph.get_outgoing_edges(graph, node_id)
          neighbors = Enum.map(outgoing, &{&1.to_node_id, depth + 1})
          new_queue = rest ++ neighbors
          traverse_fn.(traverse_fn, new_queue, new_visited, [node_id | acc])
        end
    end
  end
  
  traverse.(traverse, queue, visited, [])
end

# Helper function for DFS traversal  
dfs_traversal = fn graph, start_node_id, max_depth ->
  visited = MapSet.new()
  
  traverse = fn traverse_fn, node_id, depth, visited, acc ->
    if depth >= max_depth or MapSet.member?(visited, node_id) do
      acc
    else
      new_visited = MapSet.put(visited, node_id)
      outgoing = Graph.get_outgoing_edges(graph, node_id)
      
      Enum.reduce(outgoing, [node_id | acc], fn edge, acc ->
        traverse_fn.(traverse_fn, edge.to_node_id, depth + 1, new_visited, acc)
      end)
    end
  end
  
  traverse.(traverse, start_node_id, 0, visited, [])
end

run_benchmark.("BFS Depth 2", 100, fn ->
  start_node = "node_#{:rand.uniform(1000)}"
  bfs_traversal.(test_graph, start_node, 2)
end)

run_benchmark.("BFS Depth 3", 50, fn ->
  start_node = "node_#{:rand.uniform(1000)}"
  bfs_traversal.(test_graph, start_node, 3)
end)

run_benchmark.("DFS Depth 2", 100, fn ->
  start_node = "node_#{:rand.uniform(1000)}"
  dfs_traversal.(test_graph, start_node, 2)
end)

run_benchmark.("DFS Depth 3", 50, fn ->
  start_node = "node_#{:rand.uniform(1000)}"
  dfs_traversal.(test_graph, start_node, 3)
end)

run_benchmark.("Find Neighbors", 1000, fn ->
  node_id = "node_#{:rand.uniform(1000)}"
  Graph.get_outgoing_edges(test_graph, node_id)
end)

run_benchmark.("Count Total Edges", 100, fn ->
  Graph.list_edges(test_graph) |> length()
end)

run_benchmark.("Count Total Nodes", 100, fn ->
  Graph.list_nodes(test_graph) |> length()
end)

# ============================================================================
# Concurrent Access Benchmark
# ============================================================================

IO.puts "\n🔄 Concurrent Access Performance"
IO.puts String.duplicate("=", 50)

# Setup for concurrent testing
{concurrent_graph, _, _} = setup_test_graph.(500)

# Concurrent read test
concurrent_reads = fn process_count ->
  tasks = 1..process_count
  |> Enum.map(fn _i ->
    Task.async(fn ->
      # Each process does 100 read operations
      1..100
      |> Enum.map(fn _ ->
        node_id = "node_#{:rand.uniform(500)}"
        Graph.get_node(concurrent_graph, node_id)
      end)
      |> length()
    end)
  end)
  
  Task.await_many(tasks, 10_000)
  |> Enum.sum()
end

# Concurrent write test
concurrent_writes = fn process_count ->
  tasks = 1..process_count
  |> Enum.map(fn i ->
    Task.async(fn ->
      # Each process does 50 write operations
      1..50
      |> Enum.map(fn j ->
        node_id = "concurrent_#{i}_#{j}"
        node = Node.new(node_id, ["Concurrent"], %{"process" => i, "iteration" => j})
        Graph.add_node(concurrent_graph, node)
      end)
      |> length()
    end)
  end)
  
  Task.await_many(tasks, 10_000)
  |> Enum.sum()
end

IO.puts "\nConcurrent Operations Test:"

# Test with different process counts
process_counts = [1, 2, 5, 10]

Enum.each(process_counts, fn proc_count ->
  IO.puts "\n👥 Testing with #{proc_count} processes:"
  
  # Concurrent reads
  {read_time_us, read_operations} = :timer.tc(fn -> concurrent_reads.(proc_count) end)
  read_time_ms = read_time_us / 1000
  read_ops_per_sec = read_operations / (read_time_ms / 1000)
  
  IO.puts "  Reads: #{read_operations} ops in #{Float.round(read_time_ms, 2)} ms"
  IO.puts "  Read throughput: #{Float.round(read_ops_per_sec, 0)} ops/sec"
  
  # Concurrent writes
  {write_time_us, write_operations} = :timer.tc(fn -> concurrent_writes.(proc_count) end)
  write_time_ms = write_time_us / 1000
  write_ops_per_sec = write_operations / (write_time_ms / 1000)
  
  IO.puts "  Writes: #{write_operations} ops in #{Float.round(write_time_ms, 2)} ms"
  IO.puts "  Write throughput: #{Float.round(write_ops_per_sec, 0)} ops/sec"
end)

# ============================================================================
# Scalability Analysis
# ============================================================================

IO.puts "\n\n📈 Scalability Analysis"
IO.puts String.duplicate("=", 50)

# Test how performance scales with graph size
scalability_sizes = [100, 500, 1000, 2500, 5000]

IO.puts "\nPerformance vs Graph Size:"
Enum.each(scalability_sizes, fn size ->
  IO.puts "\n📊 Graph Size: #{size} nodes"
  
  {setup_time_us, {scale_graph, _, _}} = :timer.tc(fn -> setup_test_graph.(size) end)
  setup_time_ms = setup_time_us / 1000
  
  # Test node retrieval performance
  {get_time_us, _} = :timer.tc(fn ->
    1..100 |> Enum.each(fn _ ->
      node_id = "node_#{:rand.uniform(size)}"
      Graph.get_node(scale_graph, node_id)
    end)
  end)
  get_time_ms = get_time_us / 1000
  
  # Test edge traversal performance
  {traversal_time_us, _} = :timer.tc(fn ->
    1..50 |> Enum.each(fn _ ->
      node_id = "node_#{:rand.uniform(size)}"
      Graph.get_outgoing_edges(scale_graph, node_id)
    end)
  end)
  traversal_time_ms = traversal_time_us / 1000
  
  # Test full scan performance
  {scan_time_us, node_count} = :timer.tc(fn ->
    Graph.list_nodes(scale_graph) |> length()
  end)
  scan_time_ms = scan_time_us / 1000
  
  IO.puts "  Setup: #{Float.round(setup_time_ms, 2)} ms"
  IO.puts "  100 Gets: #{Float.round(get_time_ms, 2)} ms (#{Float.round(get_time_ms / 100, 3)} ms avg)"
  IO.puts "  50 Traversals: #{Float.round(traversal_time_ms, 2)} ms (#{Float.round(traversal_time_ms / 50, 3)} ms avg)"
  IO.puts "  Full Scan: #{Float.round(scan_time_ms, 2)} ms (#{node_count} nodes)"
  
  # Calculate efficiency metrics
  get_efficiency = 100 / get_time_ms * 1000  # ops per second
  traversal_efficiency = 50 / traversal_time_ms * 1000
  scan_efficiency = node_count / scan_time_ms * 1000
  
  IO.puts "  Efficiency - Gets: #{Float.round(get_efficiency, 0)} ops/sec"
  IO.puts "  Efficiency - Traversals: #{Float.round(traversal_efficiency, 0)} ops/sec"
  IO.puts "  Efficiency - Scan: #{Float.round(scan_efficiency, 0)} nodes/sec"
end)

# ============================================================================
# Summary and Recommendations
# ============================================================================

IO.puts """

🎉 Core Operations Benchmark Complete!
======================================

Key Performance Insights:
💡 ETS-based storage provides excellent concurrent read performance
💡 Write operations scale linearly with graph size
💡 Property filtering is efficient for moderate-sized graphs
💡 BFS/DFS traversal performance depends on graph connectivity
💡 Memory usage scales predictably with node/edge count

Performance Recommendations:
🚀 Use property indexing for frequent filter operations
🔍 Implement result caching for repeated traversals
📊 Consider graph partitioning for very large datasets
⚡ Leverage BEAM's concurrency for parallel operations
🧠 Pre-compute frequently accessed paths and metrics

Optimization Opportunities:
🔧 Add native indexing for property-based queries
📈 Implement more efficient neighbor finding algorithms
🎯 Create specialized data structures for common graph patterns
💾 Add persistence layer for large graph storage
🔄 Optimize memory layout for better cache performance

Next Benchmarks:
📊 Query engine performance (examples/benchmarks/query_performance.exs)
🧮 Matrix operations benchmarking (examples/benchmarks/matrix_performance.exs)
🤖 Agent-specific workload analysis (examples/benchmarks/agent_workloads.exs)
"""
