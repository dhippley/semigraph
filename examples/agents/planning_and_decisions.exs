#!/usr/bin/env elixir

# Agent Decision Making & Planning Example
# Demonstrates using Semigraph for AI agent planning and decision trees

Mix.install([{:semigraph, path: Path.expand("../..", __DIR__)}])

alias Semigraph.{Graph, Node, Edge}

IO.puts """
🎯 Agent Decision Making & Planning with Semigraph
=================================================

This example demonstrates:
1. Modeling decision trees as graphs
2. Creating action plans with prerequisites
3. State-based planning and goal decomposition
4. Risk assessment and alternative pathways
5. Dynamic plan adaptation and replanning
6. Multi-agent coordination patterns
"""

# ============================================================================
# Setup Planning Environment
# ============================================================================

IO.puts "\n🧠 Setting up Agent Planning System..."

{:ok, planning_graph} = Graph.new("agent_planning")

# Create agent state nodes
agent_states = [
  {"current_state", "Agent at home office", "state", %{
    "location" => "home_office",
    "time" => "09:00",
    "energy" => 80,
    "resources" => ["laptop", "coffee"],
    "status" => "ready"
  }},

  {"goal_state", "Presentation delivered successfully", "goal", %{
    "location" => "conference_room",
    "time" => "14:00",
    "success_criteria" => ["slides_complete", "demo_working", "audience_engaged"],
    "priority" => "high"
  }}
]

# Create intermediate states for planning
intermediate_states = [
  {"slides_prepared", "Presentation slides ready", "state", %{
    "completion" => 0,
    "estimated_time" => 120,  # minutes
    "prerequisites" => ["research_done", "outline_created"]
  }},

  {"demo_ready", "Live demo working", "state", %{
    "completion" => 0,
    "estimated_time" => 90,
    "prerequisites" => ["code_tested", "data_prepared"]
  }},

  {"rehearsal_done", "Presentation rehearsed", "state", %{
    "completion" => 0,
    "estimated_time" => 30,
    "prerequisites" => ["slides_prepared", "demo_ready"]
  }},

  {"travel_complete", "Arrived at venue", "state", %{
    "completion" => 0,
    "estimated_time" => 45,
    "prerequisites" => ["equipment_packed"]
  }}
]

# Create action nodes
action_nodes = [
  {"research_topic", "Research presentation topic", "action", %{
    "duration" => 60,
    "effort" => "medium",
    "resources_needed" => ["internet", "laptop"],
    "success_rate" => 0.9
  }},

  {"create_outline", "Create presentation outline", "action", %{
    "duration" => 30,
    "effort" => "low",
    "resources_needed" => ["laptop"],
    "success_rate" => 0.95
  }},

  {"build_slides", "Build presentation slides", "action", %{
    "duration" => 90,
    "effort" => "high",
    "resources_needed" => ["laptop", "design_tools"],
    "success_rate" => 0.85
  }},

  {"test_code", "Test demo code", "action", %{
    "duration" => 45,
    "effort" => "medium",
    "resources_needed" => ["laptop", "test_data"],
    "success_rate" => 0.8
  }},

  {"prepare_data", "Prepare demo data", "action", %{
    "duration" => 30,
    "effort" => "low",
    "resources_needed" => ["laptop"],
    "success_rate" => 0.9
  }},

  {"rehearse", "Rehearse presentation", "action", %{
    "duration" => 30,
    "effort" => "medium",
    "resources_needed" => ["quiet_space"],
    "success_rate" => 0.9
  }},

  {"pack_equipment", "Pack presentation equipment", "action", %{
    "duration" => 15,
    "effort" => "low",
    "resources_needed" => ["laptop", "charger", "dongle"],
    "success_rate" => 0.95
  }},

  {"travel_to_venue", "Travel to presentation venue", "action", %{
    "duration" => 45,
    "effort" => "low",
    "resources_needed" => ["transport"],
    "success_rate" => 0.9
  }}
]

# Add all nodes to the graph
all_nodes = agent_states ++ intermediate_states ++ action_nodes

{:ok, planning_graph} =
  Enum.reduce(all_nodes, {:ok, planning_graph}, fn {id, description, type, props}, {:ok, acc_graph} ->
    node = Node.new(id, [String.capitalize(type)], Map.merge(%{
      "description" => description,
      "type" => type,
      "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }, props))
    Graph.add_node(acc_graph, node)
  end)

IO.puts "✅ Created planning environment with #{length(all_nodes)} nodes"

# ============================================================================
# Create Planning Relationships
# ============================================================================

IO.puts "\n🔗 Creating Planning Relationships..."

# Define planning relationships
planning_relationships = [
  # Action -> State transitions
  {"research_topic", "slides_prepared", "ENABLES", %{"contribution" => 0.3}},
  {"create_outline", "slides_prepared", "ENABLES", %{"contribution" => 0.2}},
  {"build_slides", "slides_prepared", "COMPLETES", %{"contribution" => 0.5}},

  {"test_code", "demo_ready", "ENABLES", %{"contribution" => 0.6}},
  {"prepare_data", "demo_ready", "COMPLETES", %{"contribution" => 0.4}},

  {"pack_equipment", "travel_complete", "ENABLES", %{"contribution" => 0.3}},
  {"travel_to_venue", "travel_complete", "COMPLETES", %{"contribution" => 0.7}},

  {"rehearse", "rehearsal_done", "COMPLETES", %{"contribution" => 1.0}},

  # State prerequisites
  {"slides_prepared", "rehearsal_done", "PREREQUISITE", %{"importance" => 0.8}},
  {"demo_ready", "rehearsal_done", "PREREQUISITE", %{"importance" => 0.8}},
  {"travel_complete", "goal_state", "PREREQUISITE", %{"importance" => 1.0}},
  {"rehearsal_done", "goal_state", "PREREQUISITE", %{"importance" => 0.7}},

  # Sequential dependencies
  {"research_topic", "create_outline", "PRECEDES", %{"delay" => 0}},
  {"create_outline", "build_slides", "PRECEDES", %{"delay" => 0}},
  {"test_code", "prepare_data", "PARALLEL", %{"sync_required" => false}},

  # Resource conflicts (can't do simultaneously)
  {"build_slides", "test_code", "CONFLICTS", %{"resource" => "laptop"}},
  {"rehearse", "travel_to_venue", "CONFLICTS", %{"resource" => "time"}},

  # Alternative paths
  {"research_topic", "demo_ready", "ALTERNATIVE", %{"efficiency" => 0.6}},  # Skip slides, go demo-only
  {"current_state", "travel_complete", "EMERGENCY", %{"risk" => 0.9}}  # Skip all prep if emergency
]

{:ok, planning_graph} =
  Enum.reduce(planning_relationships, {:ok, planning_graph}, fn {from, to, rel_type, props}, {:ok, acc_graph} ->
    edge_id = "#{from}_#{rel_type}_#{to}"
    edge = Edge.new(edge_id, from, to, rel_type, props)
    Graph.add_edge(acc_graph, edge)
  end)

IO.puts "✅ Created #{length(planning_relationships)} planning relationships"

# ============================================================================
# Planning Algorithm Functions
# ============================================================================

IO.puts "\n🤖 Agent Planning Algorithms"
IO.puts String.duplicate("=", 40)

# Function to find optimal action sequence
find_action_sequence = fn graph, _start_state, _goal_state ->
  # Get all actions
  actions = Graph.list_nodes(graph, label: "Action")

  # Simple greedy planning: find actions that lead to goal
  relevant_actions =
    actions
    |> Enum.filter(fn action ->
      outgoing_edges = Graph.get_outgoing_edges(graph, action.id)
      # Check if this action contributes to any intermediate state
      Enum.any?(outgoing_edges, fn edge ->
        edge.relationship_type in ["ENABLES", "COMPLETES"]
      end)
    end)
    |> Enum.sort_by(fn action ->
      # Sort by success rate and efficiency
      success_rate = action.properties["success_rate"] || 0.5
      duration = action.properties["duration"] || 60
      -(success_rate / duration)  # Higher success rate per minute is better
    end)

  relevant_actions
end

# Function to estimate plan completion time
estimate_completion_time = fn _graph, actions ->
  total_time =
    actions
    |> Enum.map(fn action ->
      duration = action.properties["duration"] || 60
      success_rate = action.properties["success_rate"] || 0.8
      # Add extra time for potential failures and retries
      duration / success_rate
    end)
    |> Enum.sum()

  Float.round(total_time, 1)
end

# Function to assess plan risks
assess_plan_risks = fn _graph, actions ->
  risks =
    actions
    |> Enum.map(fn action ->
      success_rate = action.properties["success_rate"] || 0.8
      effort = action.properties["effort"]

      risk_score = case effort do
        "high" -> (1 - success_rate) * 1.5
        "medium" -> (1 - success_rate) * 1.0
        "low" -> (1 - success_rate) * 0.5
        _ -> (1 - success_rate)
      end

      {action.properties["description"], risk_score}
    end)
    |> Enum.sort_by(fn {_desc, risk} -> risk end, :desc)

  risks
end

# ============================================================================
# Generate Primary Plan
# ============================================================================

IO.puts "\n📋 Generating Primary Action Plan..."

primary_actions = find_action_sequence.(planning_graph, "current_state", "goal_state")
estimated_time = estimate_completion_time.(planning_graph, primary_actions)
plan_risks = assess_plan_risks.(planning_graph, primary_actions)

IO.puts "\n🎯 Recommended Action Sequence:"
Enum.with_index(primary_actions, 1)
|> Enum.each(fn {action, index} ->
  desc = action.properties["description"]
  duration = action.properties["duration"]
  effort = action.properties["effort"]
  success_rate = action.properties["success_rate"]

  IO.puts "#{index}. #{desc}"
  IO.puts "   Duration: #{duration} min | Effort: #{effort} | Success: #{trunc(success_rate * 100)}%"
end)

IO.puts "\n⏱️  Total Estimated Time: #{estimated_time} minutes (#{Float.round(estimated_time / 60, 1)} hours)"

IO.puts "\n⚠️  Risk Assessment:"
Enum.take(plan_risks, 3)
|> Enum.each(fn {desc, risk} ->
  risk_level = cond do
    risk > 0.3 -> "HIGH"
    risk > 0.15 -> "MEDIUM"
    true -> "LOW"
  end
  IO.puts "  #{risk_level}: #{desc} (#{Float.round(risk * 100, 1)}% risk)"
end)

# ============================================================================
# Alternative Plan Generation
# ============================================================================

IO.puts "\n🔄 Alternative Plan Generation"
IO.puts String.duplicate("=", 40)

# Function to generate alternative plans
generate_alternatives = fn graph, primary_actions ->
  # Find alternative paths using ALTERNATIVE edges
  all_edges = Graph.list_edges(graph)
  alternative_edges = Enum.filter(all_edges, &(&1.relationship_type == "ALTERNATIVE"))

  alternatives =
    alternative_edges
    |> Enum.map(fn edge ->
      efficiency = edge.properties["efficiency"] || 0.5
      case {Graph.get_node(graph, edge.from_node_id), Graph.get_node(graph, edge.to_node_id)} do
        {{:ok, from_node}, {:ok, to_node}} ->
          %{
            "from" => from_node.properties["description"],
            "to" => to_node.properties["description"],
            "efficiency" => efficiency,
            "type" => "shortcut"
          }
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)

  # Generate a time-constrained plan
  quick_actions =
    primary_actions
    |> Enum.filter(fn action ->
      effort = action.properties["effort"]
      duration = action.properties["duration"] || 60
      effort in ["low", "medium"] and duration <= 45
    end)

  alternatives ++ [%{
    "type" => "time_constrained",
    "actions" => quick_actions,
    "description" => "Minimal viable plan for time constraints"
  }]
end

alternatives = generate_alternatives.(planning_graph, primary_actions)

IO.puts "\n🛤️  Alternative Strategies:"
Enum.with_index(alternatives, 1)
|> Enum.each(fn {alt, index} ->
  case alt["type"] do
    "shortcut" ->
      efficiency = alt["efficiency"]
      IO.puts "#{index}. Shortcut: #{alt["from"]} → #{alt["to"]} (#{trunc(efficiency * 100)}% efficiency)"

    "time_constrained" ->
      action_count = length(alt["actions"])
      total_time = alt["actions"] |> Enum.map(&(&1.properties["duration"] || 60)) |> Enum.sum()
      IO.puts "#{index}. #{alt["description"]} (#{action_count} actions, #{total_time} min)"

    _ ->
      IO.puts "#{index}. Unknown alternative type"
  end
end)

# ============================================================================
# Dynamic Replanning Simulation
# ============================================================================

IO.puts "\n🔄 Dynamic Replanning Simulation"
IO.puts String.duplicate("=", 40)

# Simulate plan execution with unexpected events
simulate_execution = fn _graph, _actions ->
  events = [
    %{
      "time" => 30,
      "type" => "resource_unavailable",
      "description" => "Laptop battery died unexpectedly",
      "impact" => "delays coding tasks by 20 minutes"
    },
    %{
      "time" => 90,
      "type" => "external_dependency",
      "description" => "Demo data service is down",
      "impact" => "need alternative data source"
    },
    %{
      "time" => 180,
      "type" => "opportunity",
      "description" => "Colleague offers to review slides",
      "impact" => "improves quality but adds 15 minutes"
    }
  ]

  IO.puts "\n🎬 Execution Simulation:"
  _current_time = 0

  Enum.each(events, fn event ->
    time = event["time"]
    type = event["type"]
    desc = event["description"]
    impact = event["impact"]

    status = case type do
      "resource_unavailable" -> "⚠️  DISRUPTION"
      "external_dependency" -> "❌ BLOCKER"
      "opportunity" -> "✨ OPPORTUNITY"
      _ -> "📝 EVENT"
    end

    IO.puts "\nTime +#{time} min: #{status}"
    IO.puts "  Event: #{desc}"
    IO.puts "  Impact: #{impact}"

    # Simple adaptation strategies
    adaptation = case type do
      "resource_unavailable" ->
        "→ Switch to backup laptop or reschedule battery-intensive tasks"
      "external_dependency" ->
        "→ Implement fallback plan with local demo data"
      "opportunity" ->
        "→ Accept review if time permits, otherwise defer to post-presentation"
      _ ->
        "→ Continue with original plan"
    end

    IO.puts "  Response: #{adaptation}"
  end)

  events
end

execution_events = simulate_execution.(planning_graph, primary_actions)

# ============================================================================
# Multi-Agent Coordination Example
# ============================================================================

IO.puts "\n👥 Multi-Agent Coordination"
IO.puts String.duplicate("=", 40)

# Simulate coordination with other agents
coordination_scenarios = [
  %{
    "agent" => "Designer Agent",
    "capability" => "Slide design and visual optimization",
    "availability" => "2 hours",
    "coordination_cost" => 15,  # minutes
    "quality_improvement" => 0.3
  },
  %{
    "agent" => "Reviewer Agent",
    "capability" => "Content review and feedback",
    "availability" => "30 minutes",
    "coordination_cost" => 10,
    "quality_improvement" => 0.2
  },
  %{
    "agent" => "Technical Agent",
    "capability" => "Demo code optimization",
    "availability" => "1 hour",
    "coordination_cost" => 20,
    "quality_improvement" => 0.4
  }
]

IO.puts "\n🤝 Available Agent Collaborations:"
Enum.with_index(coordination_scenarios, 1)
|> Enum.each(fn {scenario, index} ->
  agent = scenario["agent"]
  capability = scenario["capability"]
  availability = scenario["availability"]
  cost = scenario["coordination_cost"]
  improvement = scenario["quality_improvement"]

  roi = improvement / (cost / 60)  # Quality improvement per hour of coordination

  IO.puts "#{index}. #{agent}"
  IO.puts "   Capability: #{capability}"
  IO.puts "   Available: #{availability} | Coordination: #{cost} min"
  IO.puts "   Quality boost: +#{trunc(improvement * 100)}% | ROI: #{Float.round(roi, 2)}"
end)

# Select best collaboration opportunities
best_collaborations =
  coordination_scenarios
  |> Enum.sort_by(fn scenario ->
    improvement = scenario["quality_improvement"]
    cost = scenario["coordination_cost"]
    -(improvement / cost)  # Negative for descending sort
  end)
  |> Enum.take(2)

IO.puts "\n🎯 Recommended Collaborations:"
Enum.each(best_collaborations, fn scenario ->
  agent = scenario["agent"]
  capability = scenario["capability"]
  IO.puts "  • #{agent}: #{capability}"
end)

# ============================================================================
# Plan Quality Assessment
# ============================================================================

IO.puts "\n📊 Plan Quality Assessment"
IO.puts String.duplicate("=", 40)

# Calculate overall plan metrics
calculate_plan_metrics = fn actions ->
  total_duration = actions |> Enum.map(&(&1.properties["duration"] || 60)) |> Enum.sum()
  avg_success_rate = actions |> Enum.map(&(&1.properties["success_rate"] || 0.8)) |> Enum.sum() |> Kernel./(length(actions))

  effort_distribution =
    actions
    |> Enum.group_by(&(&1.properties["effort"]))
    |> Enum.map(fn {effort, acts} -> {effort, length(acts)} end)
    |> Enum.into(%{})

  overall_risk = 1 - avg_success_rate

  %{
    "total_duration" => total_duration,
    "avg_success_rate" => avg_success_rate,
    "effort_distribution" => effort_distribution,
    "overall_risk" => overall_risk,
    "action_count" => length(actions)
  }
end

plan_metrics = calculate_plan_metrics.(primary_actions)

IO.puts "\n📈 Primary Plan Metrics:"
IO.puts "  Total Duration: #{plan_metrics["total_duration"]} minutes"
IO.puts "  Average Success Rate: #{Float.round(plan_metrics["avg_success_rate"] * 100, 1)}%"
IO.puts "  Overall Risk Level: #{Float.round(plan_metrics["overall_risk"] * 100, 1)}%"
IO.puts "  Total Actions: #{plan_metrics["action_count"]}"

IO.puts "\n⚡ Effort Distribution:"
effort_dist = plan_metrics["effort_distribution"]
Enum.each(effort_dist, fn {effort, count} ->
  percentage = Float.round(count / plan_metrics["action_count"] * 100, 1)
  IO.puts "  #{String.capitalize(effort || "unknown")}: #{count} actions (#{percentage}%)"
end)

# Plan optimization suggestions
IO.puts "\n💡 Plan Optimization Suggestions:"

cond do
  plan_metrics["overall_risk"] > 0.3 ->
    IO.puts "  • Consider adding buffer time for high-risk actions"
    IO.puts "  • Identify backup plans for critical path items"

  plan_metrics["total_duration"] > 300 ->
    IO.puts "  • Plan exceeds 5 hours - consider breaking into phases"
    IO.puts "  • Look for parallel execution opportunities"

  (effort_dist["high"] || 0) > 2 ->
    IO.puts "  • High effort concentration - consider delegation"
    IO.puts "  • Schedule breaks between intensive tasks"

  true ->
    IO.puts "  • Plan appears well-balanced and achievable"
    IO.puts "  • Consider adding quality checkpoints"
end

# ============================================================================
# Summary and Key Insights
# ============================================================================

IO.puts """

🎉 Agent Planning & Decision Making Complete!
============================================

You've learned how to:
✅ Model decision trees and planning graphs
✅ Create action sequences with prerequisites
✅ Implement risk assessment and alternative planning
✅ Simulate dynamic replanning during execution
✅ Coordinate multi-agent collaboration
✅ Assess and optimize plan quality

Key insights:
💡 Graphs naturally represent planning dependencies
💡 Multiple relationship types capture different planning concepts
💡 Risk assessment guides plan robustness
💡 Alternative paths provide adaptability
💡 Coordination improves outcomes but adds complexity
💡 Dynamic replanning handles unexpected events

Planning patterns demonstrated:
🎯 Goal decomposition into actionable steps
🔄 Sequential and parallel task dependencies
⚠️  Risk-based contingency planning
🤝 Multi-agent coordination and delegation
📊 Plan quality metrics and optimization
🎬 Execution simulation and adaptation

Next steps:
🚀 Implement reinforcement learning for plan optimization
🧠 Add temporal reasoning and scheduling constraints
📈 Create plan success prediction models
🔍 Explore hierarchical task networks (HTN) planning
⚡ Build real-time plan execution and monitoring systems
"""
