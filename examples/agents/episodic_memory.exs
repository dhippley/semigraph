#!/usr/bin/env elixir

# Basic Agent Memory Example
# Demonstrates using Semigraph for simple AI agent memory patterns

Mix.install([{:semigraph, path: Path.expand("../..", __DIR__)}])

alias Semigraph.{Graph, Node, Edge}

IO.puts """
🤖 Basic Agent Memory with Semigraph
====================================

This example demonstrates:
1. Creating episodic memories as graph nodes
2. Linking memories with semantic relationships
3. Retrieving relevant memories by context
4. Building simple goal and action graphs
5. Memory consolidation patterns
6. Basic forgetting strategies
"""

# ============================================================================
# Setup Agent Memory Graph
# ============================================================================

IO.puts "\n🧠 Setting up Agent Memory System..."

{:ok, memory_graph} = Graph.new("agent_memory")

# Create different types of memory nodes
memory_types = [
  # Episodic memories (events)
  {"episode_1", "Met Alice at coffee shop", "episodic", %{
    "location" => "Coffee Bean Cafe",
    "date" => "2024-07-20",
    "people" => ["Alice"],
    "emotions" => ["pleasant", "curious"],
    "importance" => 7
  }},

  {"episode_2", "Learned about graph databases", "episodic", %{
    "location" => "home",
    "date" => "2024-07-21",
    "topics" => ["graphs", "databases", "technology"],
    "emotions" => ["excited", "focused"],
    "importance" => 8
  }},

  {"episode_3", "Failed at cooking pasta", "episodic", %{
    "location" => "kitchen",
    "date" => "2024-07-22",
    "activity" => "cooking",
    "outcome" => "failure",
    "emotions" => ["frustrated", "amused"],
    "importance" => 4
  }},

  # Semantic memories (facts/knowledge)
  {"fact_1", "Alice works as a software engineer", "semantic", %{
    "person" => "Alice",
    "domain" => "career",
    "confidence" => 0.9,
    "source" => "conversation"
  }},

  {"fact_2", "Graph databases are good for relationships", "semantic", %{
    "domain" => "technology",
    "concept" => "graph_databases",
    "confidence" => 0.8,
    "source" => "learning"
  }},

  {"fact_3", "Pasta needs to be stirred while boiling", "semantic", %{
    "domain" => "cooking",
    "skill" => "pasta_cooking",
    "confidence" => 0.7,
    "source" => "experience"
  }},

  # Goals and intentions
  {"goal_1", "Learn more about graph databases", "goal", %{
    "priority" => "high",
    "status" => "active",
    "deadline" => "2024-08-01"
  }},

  {"goal_2", "Improve cooking skills", "goal", %{
    "priority" => "medium",
    "status" => "active",
    "deadline" => "2024-09-01"
  }},

  {"goal_3", "Maintain friendship with Alice", "goal", %{
    "priority" => "high",
    "status" => "ongoing",
    "deadline" => nil
  }}
]

# Add memory nodes to graph
{:ok, memory_graph} =
  Enum.reduce(memory_types, {:ok, memory_graph}, fn {id, content, type, props}, {:ok, acc_graph} ->
    memory_node = Node.new(id, ["Memory", String.capitalize(type)], Map.merge(%{
      "content" => content,
      "type" => type,
      "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "access_count" => 0
    }, props))
    Graph.add_node(acc_graph, memory_node)
  end)

IO.puts "✅ Created agent memory with #{length(memory_types)} memory nodes"

# ============================================================================
# Create Memory Relationships
# ============================================================================

IO.puts "\n🔗 Creating Memory Relationships..."

# Create semantic relationships between memories
memory_relationships = [
  # Episode to semantic memory links
  {"episode_1", "fact_1", "GENERATED", %{"strength" => 0.9}},
  {"episode_2", "fact_2", "GENERATED", %{"strength" => 0.8}},
  {"episode_3", "fact_3", "GENERATED", %{"strength" => 0.7}},

  # Goal to memory links
  {"episode_2", "goal_1", "SUPPORTS", %{"relevance" => 0.9}},
  {"episode_3", "goal_2", "SUPPORTS", %{"relevance" => 0.8}},
  {"episode_1", "goal_3", "SUPPORTS", %{"relevance" => 0.7}},
  {"fact_1", "goal_3", "SUPPORTS", %{"relevance" => 0.6}},

  # Memory similarity/association links
  {"episode_1", "episode_2", "TEMPORAL_SEQUENCE", %{"days_apart" => 1}},
  {"episode_2", "episode_3", "TEMPORAL_SEQUENCE", %{"days_apart" => 1}},
  {"fact_2", "goal_1", "TOPIC_MATCH", %{"similarity" => 0.9}},
  {"fact_3", "goal_2", "TOPIC_MATCH", %{"similarity" => 0.8}},

  # Cross-domain associations
  {"episode_1", "episode_2", "PERSON_CONTEXT", %{"person" => "Alice", "relevance" => 0.5}}
]

{:ok, memory_graph} =
  Enum.reduce(memory_relationships, {:ok, memory_graph}, fn {from, to, rel_type, props}, {:ok, acc_graph} ->
    edge_id = "#{from}_#{rel_type}_#{to}"
    edge = Edge.new(edge_id, from, to, rel_type, props)
    Graph.add_edge(acc_graph, edge)
  end)

IO.puts "✅ Created #{length(memory_relationships)} memory relationships"

# ============================================================================
# Memory Retrieval Functions
# ============================================================================

IO.puts "\n🔍 Memory Retrieval Examples"
IO.puts String.duplicate("=", 40)

# Function to retrieve memories by type
retrieve_memories_by_type = fn graph, memory_type ->
  Graph.list_nodes(graph, label: String.capitalize(memory_type))
  |> Enum.sort_by(fn node ->
    node.properties["importance"] || node.properties["priority"] || 0
  end, :desc)
end

# Function to find related memories
find_related_memories = fn graph, memory_id, _max_depth ->
  related_ids =
    Graph.get_outgoing_edges(graph, memory_id)
    |> Enum.map(&(&1.to_node_id))

  # Also get incoming relationships
  all_edges = Graph.list_edges(graph)
  incoming_ids =
    all_edges
    |> Enum.filter(&(&1.to_node_id == memory_id))
    |> Enum.map(&(&1.from_node_id))

  (related_ids ++ incoming_ids)
  |> Enum.uniq()
  |> Enum.map(fn id ->
    case Graph.get_node(graph, id) do
      {:ok, node} -> node
      {:error, _} -> nil
    end
  end)
  |> Enum.filter(& &1)
end

# Demonstrate memory retrieval
IO.puts "\n📚 All episodic memories:"
episodic_memories = retrieve_memories_by_type.(memory_graph, "episodic")
Enum.each(episodic_memories, fn memory ->
  content = memory.properties["content"]
  importance = memory.properties["importance"]
  date = memory.properties["date"]
  IO.puts "  - #{content} (#{date}, importance: #{importance})"
end)

IO.puts "\n🎯 Current goals:"
goals = retrieve_memories_by_type.(memory_graph, "goal")
Enum.each(goals, fn goal ->
  content = goal.properties["content"]
  priority = goal.properties["priority"]
  status = goal.properties["status"]
  IO.puts "  - #{content} (#{priority} priority, #{status})"
end)

# ============================================================================
# Context-Based Memory Search
# ============================================================================

IO.puts "\n🔍 Context-Based Memory Search"
IO.puts String.duplicate("=", 40)

# Function to search memories by context keywords
search_memories_by_context = fn graph, keywords ->
  all_memories = Graph.list_nodes(graph, label: "Memory")

  matching_memories =
    Enum.filter(all_memories, fn memory ->
      content = String.downcase(memory.properties["content"] || "")
      location = String.downcase(memory.properties["location"] || "")
      people = memory.properties["people"] || []
      topics = memory.properties["topics"] || []

      # Check if any keyword matches content, location, people, or topics
      Enum.any?(keywords, fn keyword ->
        keyword = String.downcase(keyword)
        String.contains?(content, keyword) or
        String.contains?(location, keyword) or
        Enum.any?(people, &String.contains?(String.downcase(&1), keyword)) or
        Enum.any?(topics, &String.contains?(String.downcase(&1), keyword))
      end)
    end)
    |> Enum.sort_by(fn memory ->
      -(memory.properties["importance"] || 5)
    end)

  matching_memories
end

# Search for memories related to "Alice"
IO.puts "\n👤 Memories related to 'Alice':"
alice_memories = search_memories_by_context.(memory_graph, ["alice"])
Enum.each(alice_memories, fn memory ->
  content = memory.properties["content"]
  type = memory.properties["type"]
  IO.puts "  - [#{type}] #{content}"
end)

# Search for memories related to "technology" or "database"
IO.puts "\n💻 Memories related to 'technology' or 'database':"
tech_memories = search_memories_by_context.(memory_graph, ["technology", "database", "graph"])
Enum.each(tech_memories, fn memory ->
  content = memory.properties["content"]
  type = memory.properties["type"]
  IO.puts "  - [#{type}] #{content}"
end)

# ============================================================================
# Memory Association Analysis
# ============================================================================

IO.puts "\n🕸️  Memory Association Analysis"
IO.puts String.duplicate("=", 40)

# Find memories related to a specific memory
IO.puts "\n🔗 Memories related to 'Met Alice at coffee shop':"
related_to_alice = find_related_memories.(memory_graph, "episode_1", 2)
Enum.each(related_to_alice, fn memory ->
  content = memory.properties["content"]
  type = memory.properties["type"]
  IO.puts "  - [#{type}] #{content}"
end)

# Analyze memory network connectivity
IO.puts "\n📊 Memory Network Analysis:"
all_memory_nodes = Graph.list_nodes(memory_graph, label: "Memory")
total_memories = length(all_memory_nodes)
total_connections = Graph.list_edges(memory_graph) |> length()

IO.puts "  - Total memories: #{total_memories}"
IO.puts "  - Total connections: #{total_connections}"
IO.puts "  - Average connections per memory: #{Float.round(total_connections / total_memories, 1)}"

# Find most connected memories
memory_connectivity =
  Enum.map(all_memory_nodes, fn memory ->
    outgoing = Graph.get_outgoing_edges(memory_graph, memory.id) |> length()

    all_edges = Graph.list_edges(memory_graph)
    incoming =
      all_edges
      |> Enum.filter(&(&1.to_node_id == memory.id))
      |> length()

    total_connections = outgoing + incoming
    {memory, total_connections}
  end)
  |> Enum.sort_by(fn {_memory, connections} -> connections end, :desc)

IO.puts "\n🌟 Most connected memories:"
Enum.take(memory_connectivity, 3)
|> Enum.each(fn {memory, connection_count} ->
  content = memory.properties["content"]
  type = memory.properties["type"]
  IO.puts "  - [#{type}] #{content} (#{connection_count} connections)"
end)

# ============================================================================
# Simple Action Planning
# ============================================================================

IO.puts "\n🎯 Simple Action Planning"
IO.puts String.duplicate("=", 40)

# Function to suggest actions based on active goals
suggest_actions_for_goals = fn graph ->
  active_goals =
    Graph.list_nodes(graph, label: "Goal")
    |> Enum.filter(fn goal ->
      goal.properties["status"] in ["active", "ongoing"]
    end)
    |> Enum.sort_by(fn goal ->
      case goal.properties["priority"] do
        "high" -> 3
        "medium" -> 2
        "low" -> 1
        _ -> 0
      end
    end, :desc)

  # For each goal, suggest actions based on related memories
  Enum.map(active_goals, fn goal ->
    # Find supporting memories
    supporting_memories = find_related_memories.(graph, goal.id, 1)

    # Generate action suggestions based on goal content and related memories
    actions = cond do
      String.contains?(goal.properties["content"], "graph") or String.contains?(goal.properties["content"], "database") ->
        ["Read documentation on graph databases", "Practice with Semigraph examples", "Build a small graph project"]
      String.contains?(goal.properties["content"], "cooking") ->
        ["Watch cooking tutorials", "Practice basic recipes", "Take a cooking class"]
      String.contains?(goal.properties["content"], "friendship") or String.contains?(goal.properties["content"], "Alice") ->
        ["Send a message to Alice", "Plan a coffee meetup", "Share interesting articles"]
      true ->
        ["Research the topic", "Make a plan", "Take first steps"]
    end

    {goal, actions, supporting_memories}
  end)
end

action_suggestions = suggest_actions_for_goals.(memory_graph)

IO.puts "\n💡 Action suggestions based on goals:"
Enum.each(action_suggestions, fn {goal, actions, supporting_memories} ->
  content = goal.properties["content"]
  priority = goal.properties["priority"]

  IO.puts "\n🎯 Goal: #{content} (#{priority} priority)"
  IO.puts "   Suggested actions:"
  Enum.each(actions, fn action ->
    IO.puts "     • #{action}"
  end)

  if length(supporting_memories) > 0 do
    IO.puts "   Based on memories:"
    Enum.take(supporting_memories, 2)
    |> Enum.each(fn memory ->
      memory_content = memory.properties["content"]
      IO.puts "     - #{memory_content}"
    end)
  end
end)

# ============================================================================
# Memory Consolidation Simulation
# ============================================================================

IO.puts "\n🔄 Memory Consolidation Simulation"
IO.puts String.duplicate("=", 40)

# Simulate memory consolidation (strengthening important connections)
consolidate_memories = fn graph ->
  all_edges = Graph.list_edges(graph)

  # Find highly important memories
  important_memories =
    Graph.list_nodes(graph, label: "Memory")
    |> Enum.filter(fn memory ->
      (memory.properties["importance"] || 5) >= 7
    end)
    |> Enum.map(&(&1.id))

  # Count connections to important memories
  consolidation_candidates =
    all_edges
    |> Enum.filter(fn edge ->
      edge.from_node_id in important_memories or edge.to_node_id in important_memories
    end)
    |> Enum.take(3)  # Take top 3 for demonstration

  consolidation_candidates
end

consolidated_connections = consolidate_memories.(memory_graph)

IO.puts "\n🧠 Memory consolidation recommendations:"
IO.puts "Strengthen these connections (they involve important memories):"

Enum.each(consolidated_connections, fn edge ->
  case {Graph.get_node(memory_graph, edge.from_node_id), Graph.get_node(memory_graph, edge.to_node_id)} do
    {{:ok, from_node}, {:ok, to_node}} ->
      from_content = from_node.properties["content"]
      to_content = to_node.properties["content"]
      rel_type = edge.relationship_type
      strength = edge.properties["strength"] || edge.properties["relevance"] || "unknown"

      IO.puts "  - #{from_content}"
      IO.puts "    #{rel_type} (strength: #{strength})"
      IO.puts "    #{to_content}"
      IO.puts ""
    _ ->
      IO.puts "  - Connection: #{edge.from_node_id} -> #{edge.to_node_id}"
  end
end)

# ============================================================================
# Summary and Insights
# ============================================================================

IO.puts "\n📊 Agent Memory System Summary"
IO.puts String.duplicate("=", 40)

episodic_count = Graph.list_nodes(memory_graph, label: "Episodic") |> length()
semantic_count = Graph.list_nodes(memory_graph, label: "Semantic") |> length()
goal_count = Graph.list_nodes(memory_graph, label: "Goal") |> length()

IO.puts "Memory System Statistics:"
IO.puts "  🎬 Episodic memories: #{episodic_count}"
IO.puts "  📚 Semantic memories: #{semantic_count}"
IO.puts "  🎯 Active goals: #{goal_count}"
IO.puts "  🔗 Total connections: #{total_connections}"

# Memory types distribution
memory_by_importance =
  Graph.list_nodes(memory_graph, label: "Memory")
  |> Enum.filter(fn memory -> memory.properties["importance"] end)
  |> Enum.group_by(fn memory ->
    case memory.properties["importance"] do
      i when i >= 8 -> "high"
      i when i >= 6 -> "medium"
      _ -> "low"
    end
  end)

IO.puts "\nMemory importance distribution:"
Enum.each(memory_by_importance, fn {importance, memories} ->
  IO.puts "  #{String.capitalize(importance)}: #{length(memories)} memories"
end)

IO.puts """

🎉 Agent Memory Example Complete!
=================================

You've learned how to:
✅ Model episodic and semantic memories as graph nodes
✅ Create semantic relationships between memories
✅ Implement context-based memory retrieval
✅ Analyze memory network connectivity
✅ Generate action suggestions from goals and memories
✅ Simulate memory consolidation processes

Key insights:
💡 Graphs naturally model associative memory
💡 Relationship types capture different memory connections
💡 Memory importance can guide consolidation
💡 Context search enables flexible memory retrieval
💡 Goals can be linked to supporting memories

Next steps:
🔍 Explore examples/domains/ for more complex memory patterns
📊 Check examples/basic/matrix_operations.exs for memory analysis
🤖 Build more sophisticated agent architectures
🧠 Implement temporal decay and forgetting mechanisms
"""
