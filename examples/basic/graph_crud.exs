#!/usr/bin/env elixir

# Semigraph CRUD Operations Example
# Demonstrates Create, Read, Update, Delete operations on graphs, nodes, and edges

Mix.install([{:semigraph, path: "../../"}])

alias Semigraph.{Graph, Node, Edge, Query}

IO.puts """
📝 Semigraph CRUD Operations Example
====================================

This example demonstrates:
1. Creating graphs, nodes, and edges
2. Reading and querying graph data
3. Updating node and edge properties
4. Deleting nodes and edges safely
5. Error handling and validation
"""

# ============================================================================
# CREATE Operations
# ============================================================================

IO.puts "\n🔨 CREATE Operations"
IO.puts String.duplicate("=", 40)

# Create multiple graphs
IO.puts "\n📊 Creating graphs..."
{:ok, main_graph} = Graph.new("main_graph")
{:ok, test_graph} = Graph.new("test_graph")
IO.puts "✅ Created graphs: main_graph, test_graph"

# Create nodes with different patterns
IO.puts "\n👤 Creating nodes..."

# Simple node
user1 = Node.new("user1", ["User"], %{"name" => "John Doe"})

# Node with multiple labels
admin1 = Node.new("admin1", ["User", "Admin"], %{
  "name" => "Jane Admin",
  "permissions" => ["read", "write", "delete"],
  "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
})

# Node with complex properties
product1 = Node.new("product1", ["Product"], %{
  "name" => "Laptop Pro",
  "price" => 1299.99,
  "specs" => %{
    "cpu" => "Intel i7",
    "ram" => "16GB",
    "storage" => "512GB SSD"
  },
  "tags" => ["electronics", "computers", "premium"]
})

# Add nodes to graph
{:ok, main_graph} = Graph.add_node(main_graph, user1)
{:ok, main_graph} = Graph.add_node(main_graph, admin1)
{:ok, main_graph} = Graph.add_node(main_graph, product1)

IO.puts "✅ Created 3 nodes with different property patterns"

# Create edges with properties
IO.puts "\n🔗 Creating edges..."

# Simple relationship
owns_edge = Edge.new("owns1", "user1", "product1", "OWNS", %{
  "purchase_date" => "2024-01-15",
  "price_paid" => 1199.99
})

# Administrative relationship
manages_edge = Edge.new("manages1", "admin1", "user1", "MANAGES", %{
  "since" => "2023-06-01",
  "level" => "supervisor"
})

{:ok, main_graph} = Graph.add_edge(main_graph, owns_edge)
{:ok, main_graph} = Graph.add_edge(main_graph, manages_edge)

IO.puts "✅ Created 2 edges with relationship properties"

# ============================================================================
# READ Operations
# ============================================================================

IO.puts "\n📖 READ Operations"
IO.puts String.duplicate("=", 40)

# Read individual nodes
IO.puts "\n🔍 Reading individual nodes..."
case Graph.get_node(main_graph, "user1") do
  {:ok, node} ->
    IO.puts "Found user1: #{node.properties["name"]}"
  {:error, :not_found} ->
    IO.puts "❌ Node not found"
end

# List all nodes
IO.puts "\n📋 Listing all nodes..."
all_nodes = Graph.list_nodes(main_graph)
IO.puts "Total nodes: #{length(all_nodes)}"
Enum.each(all_nodes, fn node ->
  labels = Enum.join(node.labels, ", ")
  IO.puts "  - #{node.id} [#{labels}]: #{node.properties["name"]}"
end)

# Filter nodes by label
IO.puts "\n🏷️  Filtering nodes by label..."
users = Graph.list_nodes(main_graph, label: "User")
IO.puts "Users found: #{length(users)}"
Enum.each(users, fn user ->
  IO.puts "  - #{user.properties["name"]} (#{user.id})"
end)

# Filter nodes by property
IO.puts "\n🔍 Filtering nodes by property..."
johns = Graph.list_nodes(main_graph, property: {"name", "John Doe"})
IO.puts "Nodes with name 'John Doe': #{length(johns)}"

# List edges
IO.puts "\n📊 Listing edges..."
all_edges = Graph.list_edges(main_graph)
IO.puts "Total edges: #{length(all_edges)}"
Enum.each(all_edges, fn edge ->
  IO.puts "  - #{edge.from_node_id} -[#{edge.relationship_type}]-> #{edge.to_node_id}"
end)

# Query using DSL
IO.puts "\n🔍 DSL Queries..."
result = main_graph
|> Query.match([{:n, :User}])
|> Query.return([{:n, :name}])
|> Query.execute()

case result do
  {:ok, %{rows: rows}} ->
    IO.puts "DSL Query - User names:"
    Enum.each(rows, fn row ->
      IO.puts "  - #{row["n.name"]}"
    end)
  {:error, reason} ->
    IO.puts "❌ Query failed: #{reason}"
end

# ============================================================================
# UPDATE Operations (Simulated)
# ============================================================================

IO.puts "\n✏️  UPDATE Operations"
IO.puts String.duplicate("=", 40)

IO.puts "\n📝 Node property updates..."
# Note: Current Semigraph doesn't have direct update methods
# We simulate by creating new nodes with updated properties

# Get the current user
{:ok, current_user} = Graph.get_node(main_graph, "user1")
IO.puts "Current user name: #{current_user.properties["name"]}"

# Create updated node (simulate update)
updated_user = Node.new("user1", ["User"], Map.put(current_user.properties, "name", "John Updated"))

# In a full implementation, you'd have Graph.update_node/2
IO.puts "🔄 In a full implementation, you would use:"
IO.puts "  {:ok, graph} = Graph.update_node(graph, updated_user)"
IO.puts "✅ Simulated name update: John Doe -> John Updated"

# Edge property updates
{:ok, owns_edge} = Graph.get_node(main_graph, "owns1") # This would be get_edge in real implementation
IO.puts "\n📝 Edge property updates..."
IO.puts "🔄 In a full implementation, you would use:"
IO.puts "  {:ok, graph} = Graph.update_edge(graph, edge_with_new_properties)"
IO.puts "✅ Simulated edge property update"

# ============================================================================
# DELETE Operations
# ============================================================================

IO.puts "\n🗑️  DELETE Operations"
IO.puts String.duplicate("=", 40)

# Create a temporary node for deletion demo
temp_node = Node.new("temp", ["Temporary"], %{"purpose" => "demo deletion"})
{:ok, main_graph} = Graph.add_node(main_graph, temp_node)

IO.puts "\n📊 Before deletion:"
nodes_before = Graph.list_nodes(main_graph)
IO.puts "Total nodes: #{length(nodes_before)}"

# Delete the temporary node
IO.puts "\n🗑️  Deleting temporary node..."
case Graph.delete_node(main_graph, "temp") do
  {:ok, updated_graph} ->
    main_graph = updated_graph
    nodes_after = Graph.list_nodes(main_graph)
    IO.puts "✅ Node deleted successfully"
    IO.puts "Total nodes after deletion: #{length(nodes_after)}"
  {:error, reason} ->
    IO.puts "❌ Deletion failed: #{reason}"
end

# Demonstrate cascading deletion
IO.puts "\n🔗 Cascading deletion demo..."
# Create nodes and edge for demo
demo_node1 = Node.new("demo1", ["Demo"], %{"name" => "Demo Node 1"})
demo_node2 = Node.new("demo2", ["Demo"], %{"name" => "Demo Node 2"})
demo_edge = Edge.new("demo_edge", "demo1", "demo2", "CONNECTS", %{})

{:ok, main_graph} = Graph.add_node(main_graph, demo_node1)
{:ok, main_graph} = Graph.add_node(main_graph, demo_node2)
{:ok, main_graph} = Graph.add_edge(main_graph, demo_edge)

edges_before = Graph.list_edges(main_graph)
IO.puts "Edges before node deletion: #{length(edges_before)}"

# Delete node (should cascade to edges)
case Graph.delete_node(main_graph, "demo1") do
  {:ok, updated_graph} ->
    main_graph = updated_graph
    edges_after = Graph.list_edges(main_graph)
    IO.puts "✅ Node deleted with cascade"
    IO.puts "Edges after deletion: #{length(edges_after)}"
  {:error, reason} ->
    IO.puts "❌ Deletion failed: #{reason}"
end

# ============================================================================
# ERROR Handling and Validation
# ============================================================================

IO.puts "\n⚠️  Error Handling & Validation"
IO.puts String.duplicate("=", 40)

# Try to get non-existent node
IO.puts "\n🔍 Attempting to get non-existent node..."
case Graph.get_node(main_graph, "nonexistent") do
  {:ok, node} ->
    IO.puts "Unexpected: found node #{node.id}"
  {:error, :not_found} ->
    IO.puts "✅ Correctly returned :not_found for non-existent node"
end

# Try to create edge with missing nodes
IO.puts "\n🔗 Attempting to create edge with missing nodes..."
invalid_edge = Edge.new("invalid", "missing1", "missing2", "INVALID", %{})
case Graph.add_edge(main_graph, invalid_edge) do
  {:ok, _graph} ->
    IO.puts "❌ Unexpected: edge creation should have failed"
  {:error, reason} ->
    IO.puts "✅ Correctly failed to create edge: #{reason}"
end

# Try to delete non-existent node
IO.puts "\n🗑️  Attempting to delete non-existent node..."
case Graph.delete_node(main_graph, "nonexistent") do
  {:ok, _graph} ->
    IO.puts "❌ Unexpected: deletion should have failed"
  {:error, reason} ->
    IO.puts "✅ Correctly failed to delete: #{reason}"
end

# ============================================================================
# Summary
# ============================================================================

IO.puts "\n📊 Final Graph State"
IO.puts String.duplicate("=", 40)

final_nodes = Graph.list_nodes(main_graph)
final_edges = Graph.list_edges(main_graph)

IO.puts "Final statistics:"
IO.puts "  - Nodes: #{length(final_nodes)}"
IO.puts "  - Edges: #{length(final_edges)}"

IO.puts "\nRemaining nodes:"
Enum.each(final_nodes, fn node ->
  labels = Enum.join(node.labels, ", ")
  name = node.properties["name"] || "unnamed"
  IO.puts "  - #{node.id} [#{labels}]: #{name}"
end)

IO.puts """

🎉 CRUD Operations Complete!
============================

You've learned how to:
✅ CREATE graphs, nodes, and edges with properties
✅ READ data using direct access and queries
✅ UPDATE node and edge properties (conceptually)
✅ DELETE nodes and edges with proper cascading
✅ Handle errors and validation properly

Key takeaways:
💡 Always check return values ({:ok, result} vs {:error, reason})
💡 Node deletion cascades to connected edges
💡 Use appropriate data types for properties
💡 Label and property filtering improves query performance
"""
