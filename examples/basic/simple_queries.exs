#!/usr/bin/env elixir

# Semigraph Query Examples
# Demonstrates various query patterns and DSL usage

Mix.install([{:semigraph, path: "../../"}])

alias Semigraph.{Graph, Node, Edge, Query}

IO.puts """
🔍 Semigraph Query Examples
===========================

This example demonstrates:
1. Basic pattern matching with MATCH
2. Filtering with WHERE conditions
3. Data projection with RETURN
4. Aggregation and grouping patterns
5. Graph traversal and pathfinding
6. Query optimization tips
"""

# Setup: Create a sample social network
IO.puts "\n🏗️  Setting up sample data..."

{:ok, graph} = Graph.new("social_network")

# Create people
people = [
  {"alice", "Alice Johnson", 28, "Engineer", "San Francisco"},
  {"bob", "Bob Smith", 32, "Designer", "New York"},
  {"charlie", "Charlie Brown", 25, "Student", "Boston"},
  {"diana", "Diana Prince", 30, "Manager", "Seattle"},
  {"eve", "Eve Adams", 35, "Scientist", "Austin"},
  {"frank", "Frank Miller", 27, "Artist", "Portland"}
]

# Add people as nodes
{:ok, graph} =
  Enum.reduce(people, {:ok, graph}, fn {id, name, age, job, city}, {:ok, acc_graph} ->
    person = Node.new(id, ["Person"], %{
      "name" => name,
      "age" => age,
      "job" => job,
      "city" => city
    })
    Graph.add_node(acc_graph, person)
  end)

# Create interests
interests = [
  {"programming", "Programming", "Technology"},
  {"design", "Design", "Creative"},
  {"music", "Music", "Arts"},
  {"hiking", "Hiking", "Outdoor"},
  {"cooking", "Cooking", "Lifestyle"}
]

{:ok, graph} =
  Enum.reduce(interests, {:ok, graph}, fn {id, name, category}, {:ok, acc_graph} ->
    interest = Node.new(id, ["Interest"], %{
      "name" => name,
      "category" => category
    })
    Graph.add_node(acc_graph, interest)
  end)

# Create relationships
relationships = [
  # Friendships
  {"alice", "bob", "FRIENDS", %{"since" => 2020, "closeness" => 8}},
  {"alice", "charlie", "FRIENDS", %{"since" => 2021, "closeness" => 6}},
  {"bob", "diana", "FRIENDS", %{"since" => 2019, "closeness" => 9}},
  {"charlie", "eve", "FRIENDS", %{"since" => 2022, "closeness" => 7}},
  {"diana", "frank", "FRIENDS", %{"since" => 2020, "closeness" => 5}},

  # Interests
  {"alice", "programming", "INTERESTED_IN", %{"level" => "expert", "years" => 8}},
  {"alice", "hiking", "INTERESTED_IN", %{"level" => "intermediate", "years" => 3}},
  {"bob", "design", "INTERESTED_IN", %{"level" => "expert", "years" => 10}},
  {"bob", "music", "INTERESTED_IN", %{"level" => "beginner", "years" => 1}},
  {"charlie", "programming", "INTERESTED_IN", %{"level" => "beginner", "years" => 2}},
  {"diana", "cooking", "INTERESTED_IN", %{"level" => "advanced", "years" => 5}},
  {"eve", "programming", "INTERESTED_IN", %{"level" => "expert", "years" => 12}},
  {"frank", "music", "INTERESTED_IN", %{"level" => "expert", "years" => 15}}
]

{:ok, graph} =
  Enum.reduce(relationships, {:ok, graph}, fn {from, to, type, props}, {:ok, acc_graph} ->
    edge_id = "#{from}_#{type}_#{to}" |> String.downcase()
    edge = Edge.new(edge_id, from, to, type, props)
    Graph.add_edge(acc_graph, edge)
  end)

IO.puts "✅ Created social network with #{length(people)} people, #{length(interests)} interests"

# ============================================================================
# Basic Pattern Matching
# ============================================================================

IO.puts "\n🎯 Basic Pattern Matching"
IO.puts String.duplicate("=", 40)

# Query 1: Find all people
IO.puts "\n👥 Query 1: Find all people"
result = graph
|> Query.match([{:p, :Person}])
|> Query.return([:p])
|> Query.execute()

case result do
  {:ok, %{rows: rows}} ->
    IO.puts "Found #{length(rows)} people:"
    Enum.each(rows, fn row ->
      person = row["p"]
      IO.puts "  - #{person.properties["name"]} (#{person.properties["job"]})"
    end)
  {:error, reason} ->
    IO.puts "❌ Query failed: #{reason}"
end

# Query 2: Find all interests
IO.puts "\n🎨 Query 2: Find all interests by category"
result = graph
|> Query.match([{:i, :Interest}])
|> Query.return([{:i, :name}, {:i, :category}])
|> Query.execute()

case result do
  {:ok, %{rows: rows}} ->
    grouped = Enum.group_by(rows, fn row -> row["i.category"] end)
    Enum.each(grouped, fn {category, interests} ->
      IO.puts "#{category}:"
      Enum.each(interests, fn row ->
        IO.puts "  - #{row["i.name"]}"
      end)
    end)
  {:error, reason} ->
    IO.puts "❌ Query failed: #{reason}"
end

# ============================================================================
# Filtering with Properties
# ============================================================================

IO.puts "\n🔍 Property-Based Filtering"
IO.puts String.duplicate("=", 40)

# Query 3: Find young people (under 30)
IO.puts "\n🧑 Query 3: Find people under 30"
result = graph
|> Query.match([{:p, :Person}])
|> Query.return([{:p, :name}, {:p, :age}])
|> Query.execute()

case result do
  {:ok, %{rows: rows}} ->
    young_people = Enum.filter(rows, fn row -> row["p.age"] < 30 end)
    IO.puts "People under 30:"
    Enum.each(young_people, fn row ->
      IO.puts "  - #{row["p.name"]} (#{row["p.age"]} years old)"
    end)
  {:error, reason} ->
    IO.puts "❌ Query failed: #{reason}"
end

# Query 4: Find people by city
IO.puts "\n🏙️  Query 4: Find people by city"
result = graph
|> Query.match([{:p, :Person}])
|> Query.return([{:p, :name}, {:p, :city}])
|> Query.execute()

case result do
  {:ok, %{rows: rows}} ->
    by_city = Enum.group_by(rows, fn row -> row["p.city"] end)
    Enum.each(by_city, fn {city, residents} ->
      IO.puts "#{city}:"
      Enum.each(residents, fn row ->
        IO.puts "  - #{row["p.name"]}"
      end)
    end)
  {:error, reason} ->
    IO.puts "❌ Query failed: #{reason}"
end

# ============================================================================
# Relationship Queries
# ============================================================================

IO.puts "\n🔗 Relationship Queries"
IO.puts String.duplicate("=", 40)

# Query 5: Find who Alice is friends with
IO.puts "\n👫 Query 5: Find Alice's friends"
alice_edges = Graph.get_outgoing_edges(graph, "alice")
friend_edges = Enum.filter(alice_edges, &(&1.relationship_type == "FRIENDS"))

IO.puts "Alice's friends:"
Enum.each(friend_edges, fn edge ->
  case Graph.get_node(graph, edge.to_node_id) do
    {:ok, friend} ->
      closeness = edge.properties["closeness"]
      since = edge.properties["since"]
      IO.puts "  - #{friend.properties["name"]} (friends since #{since}, closeness: #{closeness}/10)"
    {:error, _} ->
      IO.puts "  - Unknown friend (#{edge.to_node_id})"
  end
end)

# Query 6: Find mutual interests
IO.puts "\n🎯 Query 6: Find people interested in programming"
# Get all edges where relationship is INTERESTED_IN and to_node is programming
all_edges = Graph.list_edges(graph)
programming_fans =
  all_edges
  |> Enum.filter(fn edge ->
    edge.relationship_type == "INTERESTED_IN" and edge.to_node_id == "programming"
  end)
  |> Enum.map(fn edge ->
    {:ok, person} = Graph.get_node(graph, edge.from_node_id)
    {person, edge.properties}
  end)

IO.puts "People interested in programming:"
Enum.each(programming_fans, fn {person, interest_props} ->
  level = interest_props["level"]
  years = interest_props["years"]
  IO.puts "  - #{person.properties["name"]} (#{level}, #{years} years)"
end)

# ============================================================================
# Graph Traversal
# ============================================================================

IO.puts "\n🗺️  Graph Traversal"
IO.puts String.duplicate("=", 40)

# Query 7: Find nodes connected to Alice
IO.puts "\n🌐 Query 7: Find all nodes connected to Alice (depth 2)"
connected = Query.traverse(graph, "alice", max_depth: 2)
connected_by_type = Enum.group_by(connected, fn node ->
  Enum.join(node.labels, ", ")
end)

Enum.each(connected_by_type, fn {type, nodes} ->
  IO.puts "#{type}:"
  Enum.each(nodes, fn node ->
    name = node.properties["name"] || node.id
    IO.puts "  - #{name}"
  end)
end)

# Query 8: Shortest path between people
IO.puts "\n🛤️  Query 8: Shortest path from Alice to Eve"
case Query.shortest_path(graph, "alice", "eve") do
  {:ok, path} ->
    path_names = Enum.map(path, fn node ->
      node.properties["name"] || node.id
    end)
    IO.puts "Shortest path: #{Enum.join(path_names, " → ")}"
  {:error, :no_path} ->
    IO.puts "No direct path found between Alice and Eve"
end

# ============================================================================
# Advanced Queries
# ============================================================================

IO.puts "\n🚀 Advanced Query Patterns"
IO.puts String.duplicate("=", 40)

# Query 9: Find expert programmers
IO.puts "\n💻 Query 9: Find expert programmers"
expert_programmers =
  all_edges
  |> Enum.filter(fn edge ->
    edge.relationship_type == "INTERESTED_IN" and
    edge.to_node_id == "programming" and
    edge.properties["level"] == "expert"
  end)
  |> Enum.map(fn edge ->
    {:ok, person} = Graph.get_node(graph, edge.from_node_id)
    {person, edge.properties["years"]}
  end)
  |> Enum.sort_by(fn {_person, years} -> years end, :desc)

IO.puts "Expert programmers (by experience):"
Enum.each(expert_programmers, fn {person, years} ->
  job = person.properties["job"]
  IO.puts "  - #{person.properties["name"]} (#{job}, #{years} years)"
end)

# Query 10: Social network analysis
IO.puts "\n📊 Query 10: Social network analysis"
friend_edges = Enum.filter(all_edges, &(&1.relationship_type == "FRIENDS"))

# Most social person (most friendships)
friendship_counts =
  friend_edges
  |> Enum.flat_map(fn edge -> [edge.from_node_id, edge.to_node_id] end)
  |> Enum.frequencies()
  |> Enum.sort_by(fn {_person, count} -> count end, :desc)

IO.puts "Most social people:"
Enum.take(friendship_counts, 3)
|> Enum.each(fn {person_id, friend_count} ->
  {:ok, person} = Graph.get_node(graph, person_id)
  IO.puts "  - #{person.properties["name"]}: #{friend_count} friendships"
end)

# Average friendship closeness
total_closeness =
  friend_edges
  |> Enum.map(fn edge -> edge.properties["closeness"] end)
  |> Enum.sum()

avg_closeness = total_closeness / length(friend_edges)
IO.puts "\nAverage friendship closeness: #{Float.round(avg_closeness, 1)}/10"

# ============================================================================
# Query Performance Tips
# ============================================================================

IO.puts "\n⚡ Query Performance Tips"
IO.puts String.duplicate("=", 40)

IO.puts """
💡 Performance optimization strategies:

1. 🏷️  Use label filtering when possible:
   ✅ Query.match([{:n, :Person}])  # Uses label index
   ❌ Query.match([{:n}])          # Scans all nodes

2. 🔍 Filter early in the pipeline:
   ✅ Filter by properties before expensive operations
   ❌ Compute expensive operations then filter

3. 📊 Use property indexes for common queries:
   ✅ Graph.list_nodes(graph, property: {"city", "Seattle"})
   ❌ Get all nodes then filter by city

4. 🎯 Limit traversal depth:
   ✅ Query.traverse(graph, node, max_depth: 3)
   ❌ Deep traversals without limits

5. 📈 Consider graph size:
   - Small graphs (<1000 nodes): Any query pattern works
   - Medium graphs (<10K nodes): Optimize common patterns
   - Large graphs (>10K nodes): Use indexes and limit results
"""

# ============================================================================
# Summary
# ============================================================================

IO.puts "\n📊 Query Summary"
IO.puts String.duplicate("=", 40)

total_nodes = Graph.list_nodes(graph) |> length()
total_edges = Graph.list_edges(graph) |> length()

IO.puts "Graph statistics:"
IO.puts "  - Total nodes: #{total_nodes}"
IO.puts "  - Total edges: #{total_edges}"
IO.puts "  - Average degree: #{Float.round(total_edges * 2 / total_nodes, 1)}"

IO.puts """

🎉 Query Examples Complete!
===========================

You've learned how to:
✅ Match nodes and edges with patterns
✅ Filter results using properties
✅ Project specific data with RETURN
✅ Traverse graphs and find paths
✅ Analyze social networks
✅ Optimize query performance

Next steps:
🔍 Explore examples/domains/ for domain-specific patterns
📊 Check examples/basic/matrix_operations.exs for algebraic queries
🤖 Look at examples/agents/ for AI agent query patterns
"""
