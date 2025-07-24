#!/usr/bin/env elixir

# Getting Started with Semigraph
# This example demonstrates the basic usage of Semigraph for creating and querying graphs

Mix.install([{:semigraph, path: "../../"}])

alias Semigraph.{Graph, Node, Edge, Query}

IO.puts """
🚀 Semigraph Getting Started Example
====================================

This example will show you:
1. Creating a new graph
2. Adding nodes with properties and labels
3. Creating relationships between nodes
4. Querying the graph using both DSL and string queries
5. Traversing and finding paths
"""

# Step 1: Create a new graph
IO.puts "\n📊 Step 1: Creating a new graph..."
{:ok, graph} = Graph.new("my_first_graph")
IO.puts "✅ Created graph: #{graph.name}"

# Step 2: Create some nodes
IO.puts "\n👥 Step 2: Adding nodes..."

# Create person nodes
alice = Node.new("alice", ["Person"], %{
  "name" => "Alice Johnson",
  "age" => 30,
  "role" => "Engineer"
})

bob = Node.new("bob", ["Person"], %{
  "name" => "Bob Smith",
  "age" => 25,
  "role" => "Designer"
})

charlie = Node.new("charlie", ["Person"], %{
  "name" => "Charlie Brown",
  "age" => 35,
  "role" => "Manager"
})

# Create a company node
acme = Node.new("acme", ["Company"], %{
  "name" => "ACME Corp",
  "industry" => "Technology",
  "founded" => 2010
})

# Add nodes to the graph
{:ok, graph} = Graph.add_node(graph, alice)
{:ok, graph} = Graph.add_node(graph, bob)
{:ok, graph} = Graph.add_node(graph, charlie)
{:ok, graph} = Graph.add_node(graph, acme)

IO.puts "✅ Added 4 nodes: 3 people and 1 company"

# Step 3: Create relationships
IO.puts "\n🔗 Step 3: Creating relationships..."

# People know each other
knows_edge1 = Edge.new("knows1", "alice", "bob", "KNOWS", %{"since" => 2020})
knows_edge2 = Edge.new("knows2", "bob", "charlie", "KNOWS", %{"since" => 2019})
knows_edge3 = Edge.new("knows3", "alice", "charlie", "KNOWS", %{"since" => 2018})

# People work at the company
works_edge1 = Edge.new("works1", "alice", "acme", "WORKS_AT", %{"start_date" => "2020-01-15"})
works_edge2 = Edge.new("works2", "bob", "acme", "WORKS_AT", %{"start_date" => "2021-03-01"})
works_edge3 = Edge.new("works3", "charlie", "acme", "WORKS_AT", %{"start_date" => "2019-06-10"})

# Add edges to the graph
{:ok, graph} = Graph.add_edge(graph, knows_edge1)
{:ok, graph} = Graph.add_edge(graph, knows_edge2)
{:ok, graph} = Graph.add_edge(graph, knows_edge3)
{:ok, graph} = Graph.add_edge(graph, works_edge1)
{:ok, graph} = Graph.add_edge(graph, works_edge2)
{:ok, graph} = Graph.add_edge(graph, works_edge3)

IO.puts "✅ Added 6 relationships: 3 KNOWS and 3 WORKS_AT"

# Step 4: Query the graph using DSL
IO.puts "\n🔍 Step 4: Querying with DSL..."

# Find all people
result = graph
|> Query.match([{:n, :Person}])
|> Query.return([:n])
|> Query.execute()

case result do
  {:ok, %{rows: rows}} ->
    IO.puts "Found #{length(rows)} people:"
    Enum.each(rows, fn row ->
      person = row["n"]
      IO.puts "  - #{person.properties["name"]} (#{person.properties["role"]})"
    end)
  {:error, reason} ->
    IO.puts "Query failed: #{reason}"
end

# Find people's names and ages
IO.puts "\n📋 Querying specific properties..."
result = graph
|> Query.match([{:n, :Person}])
|> Query.return([{:n, :name}, {:n, :age}])
|> Query.execute()

case result do
  {:ok, %{rows: rows}} ->
    IO.puts "People and their ages:"
    Enum.each(rows, fn row ->
      name = row["n.name"]
      age = row["n.age"]
      IO.puts "  - #{name}: #{age} years old"
    end)
  {:error, reason} ->
    IO.puts "Query failed: #{reason}"
end

# Step 5: Graph traversal
IO.puts "\n🗺️  Step 5: Graph traversal..."

# Find nodes connected to Alice (within 2 hops)
connected_nodes = Query.traverse(graph, "alice", max_depth: 2)
IO.puts "Nodes connected to Alice (within 2 hops):"
Enum.each(connected_nodes, fn node ->
  IO.puts "  - #{node.properties["name"] || node.id} (#{Enum.join(node.labels, ", ")})"
end)

# Find shortest path between Alice and Charlie
case Query.shortest_path(graph, "alice", "charlie") do
  {:ok, path} ->
    IO.puts "\nShortest path from Alice to Charlie:"
    path_names = Enum.map(path, &(&1.properties["name"] || &1.id))
    IO.puts "  #{Enum.join(path_names, " -> ")}"
  {:error, :no_path} ->
    IO.puts "\nNo path found between Alice and Charlie"
end

# Step 6: String queries (if parser supports them)
IO.puts "\n📝 Step 6: String queries..."

case Query.execute(graph, "MATCH (n:Person) RETURN n") do
  {:ok, %{rows: rows}} ->
    IO.puts "String query successful! Found #{length(rows)} people."
  {:error, _reason} ->
    IO.puts "String queries not fully supported yet (parser limitations)"
    IO.puts "💡 Use the DSL for now: Query.match([{:n, :Person}]) |> Query.return([:n])"
end

# Step 7: Graph statistics
IO.puts "\n📊 Step 7: Graph statistics..."
all_nodes = Graph.list_nodes(graph)
all_edges = Graph.list_edges(graph)

IO.puts "Graph Summary:"
IO.puts "  - Total nodes: #{length(all_nodes)}"
IO.puts "  - Total edges: #{length(all_edges)}"

# Group nodes by labels
nodes_by_label = Enum.group_by(all_nodes, fn node ->
  Enum.join(node.labels, ", ")
end)

IO.puts "  - Node types:"
Enum.each(nodes_by_label, fn {labels, nodes} ->
  IO.puts "    * #{labels}: #{length(nodes)} nodes"
end)

# Group edges by relationship type
edges_by_type = Enum.group_by(all_edges, &(&1.relationship_type))

IO.puts "  - Relationship types:"
Enum.each(edges_by_type, fn {rel_type, edges} ->
  IO.puts "    * #{rel_type}: #{length(edges)} relationships"
end)

IO.puts """

🎉 Congratulations!
You've successfully:
✅ Created a graph with nodes and relationships
✅ Queried the graph using the Semigraph DSL
✅ Performed graph traversal and pathfinding
✅ Analyzed graph structure and statistics

Next steps:
🔍 Explore examples/domains/ for real-world use cases
📊 Check examples/basic/matrix_operations.exs for algebra features
🤖 Look at examples/agents/ for AI agent memory patterns
"""
