#!/usr/bin/env elixir

# Social Network Graph Example
# Demonstrates using Semigraph for social media and networking applications

Mix.install([{:semigraph, path: "../../"}])

alias Semigraph.{Graph, Node, Edge}

IO.puts """
🌐 Social Network with Semigraph
================================

This example demonstrates:
1. Building a social network graph
2. Friend recommendations
3. Mutual connections analysis
4. Community detection patterns
5. Influence and popularity metrics
6. Content sharing and engagement
"""

# ============================================================================
# Setup Social Network Data
# ============================================================================

IO.puts "\n🏗️  Building Social Network..."

{:ok, social_graph} = Graph.new("social_network")

# Create users with detailed profiles
users = [
  {"alice", "Alice Johnson", 28, "Software Engineer", ["tech", "hiking", "photography"], "San Francisco"},
  {"bob", "Bob Smith", 32, "UX Designer", ["design", "art", "music"], "New York"},
  {"charlie", "Charlie Brown", 25, "Data Scientist", ["ai", "math", "gaming"], "Boston"},
  {"diana", "Diana Prince", 30, "Product Manager", ["business", "travel", "cooking"], "Seattle"},
  {"eve", "Eve Adams", 35, "DevOps Engineer", ["tech", "climbing", "coffee"], "Austin"},
  {"frank", "Frank Miller", 27, "Graphic Designer", ["art", "gaming", "music"], "Portland"},
  {"grace", "Grace Lee", 29, "Marketing Manager", ["marketing", "fitness", "reading"], "Denver"},
  {"henry", "Henry Wilson", 33, "Backend Engineer", ["tech", "cycling", "podcasts"], "Chicago"},
  {"iris", "Iris Chen", 26, "Frontend Developer", ["tech", "design", "travel"], "Los Angeles"},
  {"jack", "Jack Davis", 31, "Sales Director", ["business", "golf", "networking"], "Miami"}
]

# Add users to graph
{:ok, social_graph} =
  Enum.reduce(users, {:ok, social_graph}, fn {id, name, age, job, interests, city}, {:ok, acc_graph} ->
    user = Node.new(id, ["User"], %{
      "name" => name,
      "age" => age,
      "job" => job,
      "interests" => interests,
      "city" => city,
      "follower_count" => Enum.random(100..5000),
      "post_count" => Enum.random(50..500),
      "joined_date" => Date.add(Date.utc_today(), -Enum.random(30..365))
    })
    Graph.add_node(acc_graph, user)
  end)

# Helper function to categorize interests
categorize_interest = fn interest ->
  case interest do
    i when i in ["tech", "ai", "math"] -> "Technology"
    i when i in ["design", "art", "music", "photography"] -> "Creative"
    i when i in ["business", "marketing", "networking"] -> "Professional"
    i when i in ["hiking", "climbing", "cycling", "fitness", "golf"] -> "Sports"
    i when i in ["travel", "cooking", "reading", "podcasts", "coffee"] -> "Lifestyle"
    _ -> "Other"
  end
end

# Create interest nodes
interests = ["tech", "design", "art", "music", "gaming", "ai", "math", "business",
            "travel", "cooking", "hiking", "photography", "climbing", "coffee",
            "marketing", "fitness", "reading", "cycling", "podcasts", "golf", "networking"]

{:ok, social_graph} =
  Enum.reduce(interests, {:ok, social_graph}, fn interest, {:ok, acc_graph} ->
    interest_node = Node.new("interest_#{interest}", ["Interest"], %{
      "name" => String.capitalize(interest),
      "category" => categorize_interest.(interest)
    })
    Graph.add_node(acc_graph, interest_node)
  end)

# Create social connections (friendships, follows, etc.)
social_connections = [
  # Close friend circles
  {"alice", "bob", "FRIENDS", %{"strength" => 9, "since" => "2020-01-15"}},
  {"alice", "charlie", "FRIENDS", %{"strength" => 8, "since" => "2021-03-10"}},
  {"bob", "diana", "FRIENDS", %{"strength" => 7, "since" => "2019-06-20"}},
  {"charlie", "eve", "FRIENDS", %{"strength" => 8, "since" => "2020-11-05"}},
  {"diana", "grace", "FRIENDS", %{"strength" => 9, "since" => "2018-09-12"}},

  # Professional connections
  {"alice", "henry", "COLLEAGUES", %{"company" => "TechCorp", "since" => "2022-01-01"}},
  {"eve", "henry", "COLLEAGUES", %{"company" => "TechCorp", "since" => "2021-08-15"}},
  {"bob", "frank", "COLLEAGUES", %{"company" => "DesignStudio", "since" => "2020-05-10"}},
  {"diana", "grace", "COLLEAGUES", %{"company" => "ProductCo", "since" => "2019-03-01"}},

  # Follow relationships (asymmetric)
  {"frank", "alice", "FOLLOWS", %{"reason" => "tech_inspiration"}},
  {"iris", "bob", "FOLLOWS", %{"reason" => "design_inspiration"}},
  {"jack", "diana", "FOLLOWS", %{"reason" => "business_insights"}},
  {"grace", "charlie", "FOLLOWS", %{"reason" => "data_science"}},
  {"henry", "eve", "FOLLOWS", %{"reason" => "devops_tips"}},

  # Mutual follows
  {"alice", "iris", "FOLLOWS", %{"reason" => "frontend_tips"}},
  {"iris", "alice", "FOLLOWS", %{"reason" => "backend_tips"}},
  {"charlie", "henry", "FOLLOWS", %{"reason" => "engineering"}},
  {"henry", "charlie", "FOLLOWS", %{"reason" => "data_insights"}}
]

{:ok, social_graph} =
  Enum.reduce(social_connections, {:ok, social_graph}, fn {from, to, type, props}, {:ok, acc_graph} ->
    edge_id = "#{from}_#{type}_#{to}_#{System.unique_integer()}"
    edge = Edge.new(edge_id, from, to, type, props)
    Graph.add_edge(acc_graph, edge)
  end)

# Create interest relationships
{:ok, social_graph} =
  Enum.reduce(users, {:ok, social_graph}, fn {user_id, _, _, _, user_interests, _}, {:ok, acc_graph} ->
    Enum.reduce(user_interests, {:ok, acc_graph}, fn interest, {:ok, inner_graph} ->
      edge_id = "#{user_id}_interested_#{interest}"
      edge = Edge.new(edge_id, user_id, "interest_#{interest}", "INTERESTED_IN", %{
        "level" => Enum.random(["beginner", "intermediate", "advanced", "expert"])
      })
      Graph.add_edge(inner_graph, edge)
    end)
  end)

IO.puts "✅ Created social network with #{length(users)} users and #{length(interests)} interests"

# ============================================================================
# Friend Recommendations
# ============================================================================

IO.puts "\n🤝 Friend Recommendations"
IO.puts String.duplicate("=", 40)

# Function to find friend recommendations for a user
find_friend_recommendations = fn graph, user_id, limit ->
  # Get user's current friends
  user_edges = Graph.get_outgoing_edges(graph, user_id)
  current_friends =
    user_edges
    |> Enum.filter(&(&1.relationship_type == "FRIENDS"))
    |> Enum.map(&(&1.to_node_id))
    |> MapSet.new()

  # Get friends of friends
  friends_of_friends =
    current_friends
    |> Enum.flat_map(fn friend_id ->
      Graph.get_outgoing_edges(graph, friend_id)
      |> Enum.filter(&(&1.relationship_type == "FRIENDS"))
      |> Enum.map(&(&1.to_node_id))
    end)
    |> Enum.frequencies()
    |> Enum.reject(fn {candidate_id, _count} ->
      candidate_id == user_id or MapSet.member?(current_friends, candidate_id)
    end)
    |> Enum.sort_by(fn {_id, mutual_count} -> mutual_count end, :desc)
    |> Enum.take(limit)

  friends_of_friends
end

# Demonstrate friend recommendations for Alice
IO.puts "\n👥 Friend recommendations for Alice:"
alice_recommendations = find_friend_recommendations.(social_graph, "alice", 3)

Enum.each(alice_recommendations, fn {candidate_id, mutual_count} ->
  case Graph.get_node(social_graph, candidate_id) do
    {:ok, candidate} ->
      name = candidate.properties["name"]
      job = candidate.properties["job"]
      IO.puts "  - #{name} (#{job}) - #{mutual_count} mutual friends"
    {:error, _} ->
      IO.puts "  - #{candidate_id} (unknown) - #{mutual_count} mutual friends"
  end
end)

# ============================================================================
# Mutual Connections Analysis
# ============================================================================

IO.puts "\n🔗 Mutual Connections Analysis"
IO.puts String.duplicate("=", 40)

# Function to find mutual connections between two users
find_mutual_connections = fn graph, user1_id, user2_id ->
  user1_friends =
    Graph.get_outgoing_edges(graph, user1_id)
    |> Enum.filter(&(&1.relationship_type == "FRIENDS"))
    |> Enum.map(&(&1.to_node_id))
    |> MapSet.new()

  user2_friends =
    Graph.get_outgoing_edges(graph, user2_id)
    |> Enum.filter(&(&1.relationship_type == "FRIENDS"))
    |> Enum.map(&(&1.to_node_id))
    |> MapSet.new()

  MapSet.intersection(user1_friends, user2_friends)
  |> MapSet.to_list()
end

# Find mutual connections between Alice and Eve
mutual_friends = find_mutual_connections.(social_graph, "alice", "eve")
IO.puts "\n👫 Mutual friends between Alice and Eve:"

if length(mutual_friends) > 0 do
  Enum.each(mutual_friends, fn friend_id ->
    case Graph.get_node(social_graph, friend_id) do
      {:ok, friend} ->
        IO.puts "  - #{friend.properties["name"]}"
      {:error, _} ->
        IO.puts "  - #{friend_id} (unknown)"
    end
  end)
else
  IO.puts "  No mutual friends found"
end

# ============================================================================
# Community Detection (Simple)
# ============================================================================

IO.puts "\n🏘️  Community Detection"
IO.puts String.duplicate("=", 40)

# Find communities based on mutual interests
find_interest_communities = fn graph ->
  all_users = Graph.list_nodes(graph, label: "User")

  # Group users by shared interests
  user_interests =
    Enum.map(all_users, fn user ->
      interests =
        Graph.get_outgoing_edges(graph, user.id)
        |> Enum.filter(&(&1.relationship_type == "INTERESTED_IN"))
        |> Enum.map(&(&1.to_node_id))

      {user.id, user.properties["name"], interests}
    end)

  # Find groups with high interest overlap
  interest_groups =
    user_interests
    |> Enum.flat_map(fn {user_id, name, interests} ->
      Enum.map(interests, fn interest ->
        {interest, {user_id, name}}
      end)
    end)
    |> Enum.group_by(fn {interest, _user} -> interest end, fn {_interest, user} -> user end)
    |> Enum.filter(fn {_interest, users} -> length(users) >= 2 end)

  interest_groups
end

communities = find_interest_communities.(social_graph)
IO.puts "\n🎯 Interest-based communities:"

Enum.take(communities, 5)
|> Enum.each(fn {interest, members} ->
  interest_name = String.replace(interest, "interest_", "") |> String.capitalize()
  IO.puts "#{interest_name} Community (#{length(members)} members):"
  Enum.each(members, fn {_user_id, name} ->
    IO.puts "  - #{name}"
  end)
  IO.puts ""
end)

# ============================================================================
# Influence and Popularity Metrics
# ============================================================================

IO.puts "\n📊 Influence & Popularity Metrics"
IO.puts String.duplicate("=", 40)

# Calculate influence metrics
all_users = Graph.list_nodes(social_graph, label: "User")

user_metrics =
  Enum.map(all_users, fn user ->
    # Count followers
    all_edges = Graph.list_edges(social_graph)
    followers =
      all_edges
      |> Enum.filter(fn edge ->
        edge.relationship_type == "FOLLOWS" and edge.to_node_id == user.id
      end)
      |> length()

    # Count following
    following =
      Graph.get_outgoing_edges(social_graph, user.id)
      |> Enum.filter(&(&1.relationship_type == "FOLLOWS"))
      |> length()

    # Count friends
    friends =
      Graph.get_outgoing_edges(social_graph, user.id)
      |> Enum.filter(&(&1.relationship_type == "FRIENDS"))
      |> length()

    # Calculate engagement ratio
    post_count = user.properties["post_count"]
    follower_count = user.properties["follower_count"]
    engagement_ratio = if follower_count > 0, do: post_count / follower_count, else: 0

    {user, %{
      followers: followers,
      following: following,
      friends: friends,
      posts: post_count,
      engagement_ratio: engagement_ratio
    }}
  end)

# Top influencers by followers
IO.puts "\n🌟 Top Influencers (by followers):"
user_metrics
|> Enum.sort_by(fn {_user, metrics} -> metrics.followers end, :desc)
|> Enum.take(5)
|> Enum.each(fn {user, metrics} ->
  name = user.properties["name"]
  job = user.properties["job"]
  IO.puts "  - #{name} (#{job}): #{metrics.followers} followers, #{metrics.posts} posts"
end)

# Most social users (by connections)
IO.puts "\n🤝 Most Social Users (by total connections):"
user_metrics
|> Enum.sort_by(fn {_user, metrics} ->
  metrics.followers + metrics.following + metrics.friends
end, :desc)
|> Enum.take(5)
|> Enum.each(fn {user, metrics} ->
  name = user.properties["name"]
  total_connections = metrics.followers + metrics.following + metrics.friends
  IO.puts "  - #{name}: #{total_connections} total connections (#{metrics.friends} friends, #{metrics.followers} followers)"
end)

# ============================================================================
# Content Sharing Simulation
# ============================================================================

IO.puts "\n📱 Content Sharing Simulation"
IO.puts String.duplicate("=", 40)

# Simulate a viral post spreading through the network
simulate_viral_post = fn graph, author_id, content_type, _max_hops ->
  # Start with the author's immediate connections
  author_connections =
    Graph.get_outgoing_edges(graph, author_id)
    |> Enum.filter(&(&1.relationship_type in ["FRIENDS", "FOLLOWS"]))
    |> Enum.map(&(&1.to_node_id))

  # Simulate spread based on interest compatibility
  initial_reach =
    author_connections
    |> Enum.map(fn user_id ->
      case Graph.get_node(graph, user_id) do
        {:ok, user} ->
          # Higher chance of sharing if user has related interests
          interests = user.properties["interests"]
          interest_match = content_type in interests
          share_probability = if interest_match, do: 0.8, else: 0.3

          if :rand.uniform() < share_probability do
            {user.id, user.properties["name"], 1}
          else
            nil
          end
        {:error, _} -> nil
      end
    end)
    |> Enum.filter(& &1)

  # Calculate total reach (simplified)
  total_reach =
    initial_reach
    |> Enum.reduce(0, fn {_id, _name, _hop}, acc ->
      acc + Enum.random(5..50)  # Each share reaches 5-50 additional people
    end)

  {initial_reach, total_reach}
end

# Simulate Alice posting tech content
IO.puts "\n🚀 Simulating viral post: Alice shares a tech article"
{initial_shares, total_reach} = simulate_viral_post.(social_graph, "alice", "tech", 3)

IO.puts "Initial shares:"
Enum.each(initial_shares, fn {_id, name, _hop} ->
  IO.puts "  - #{name} shared the post"
end)

IO.puts "\nTotal estimated reach: #{total_reach} people"

# ============================================================================
# Network Analysis Summary
# ============================================================================

IO.puts "\n📈 Network Analysis Summary"
IO.puts String.duplicate("=", 40)

total_users = Graph.list_nodes(social_graph, label: "User") |> length()
total_relationships = Graph.list_edges(social_graph) |> length()
total_interests = Graph.list_nodes(social_graph, label: "Interest") |> length()

# Calculate network density
max_possible_edges = total_users * (total_users - 1) / 2
friend_edges =
  Graph.list_edges(social_graph)
  |> Enum.filter(&(&1.relationship_type == "FRIENDS"))
  |> length()

network_density = friend_edges / max_possible_edges * 100

IO.puts "Network Statistics:"
IO.puts "  📊 Total Users: #{total_users}"
IO.puts "  🔗 Total Relationships: #{total_relationships}"
IO.puts "  🎯 Total Interests: #{total_interests}"
IO.puts "  🌐 Network Density: #{Float.round(network_density, 1)}%"

# Average connections per user
avg_connections = total_relationships / total_users
IO.puts "  📈 Average Connections per User: #{Float.round(avg_connections, 1)}"

IO.puts """

🎉 Social Network Analysis Complete!
====================================

You've learned how to:
✅ Build complex social network graphs
✅ Implement friend recommendation algorithms
✅ Analyze mutual connections and communities
✅ Calculate influence and popularity metrics
✅ Simulate content viral spreading
✅ Perform comprehensive network analysis

Key insights:
💡 Graph databases excel at relationship queries
💡 Social networks exhibit small-world properties
💡 Interest-based communities emerge naturally
💡 Influence metrics can guide content strategy
💡 Viral spread depends on network topology

Next steps:
🔍 Explore examples/domains/knowledge_graph.exs for knowledge modeling
🤖 Check examples/agents/ for AI agent social networks
📊 Look at examples/basic/matrix_operations.exs for algebraic analysis
"""
