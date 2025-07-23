defmodule Semigraph.GraphTest do
  use ExUnit.Case, async: true

  alias Semigraph.{Graph, Node, Edge, Query}

  setup do
    {:ok, graph} = Graph.new("test_graph_#{System.unique_integer()}")
    {:ok, graph: graph}
  end

  describe "Graph CRUD operations" do
    test "creates a new graph", %{graph: graph} do
      assert %Graph{} = graph
      assert graph.name =~ "test_graph"
    end

    test "adds and retrieves nodes", %{graph: graph} do
      node = Node.new("alice", ["Person"], %{name: "Alice", age: 30})

      assert {:ok, _graph} = Graph.add_node(graph, node)
      assert {:ok, retrieved_node} = Graph.get_node(graph, "alice")
      assert retrieved_node.id == "alice"
      assert "Person" in retrieved_node.labels
      assert retrieved_node.properties.name == "Alice"
    end

    test "adds and validates edges", %{graph: graph} do
      node1 = Node.new("alice", ["Person"], %{name: "Alice"})
      node2 = Node.new("bob", ["Person"], %{name: "Bob"})

      {:ok, _graph} = Graph.add_node(graph, node1)
      {:ok, _graph} = Graph.add_node(graph, node2)

      edge = Edge.new("knows1", "alice", "bob", "KNOWS", %{since: 2020})
      assert {:ok, _graph} = Graph.add_edge(graph, edge)
    end

    test "rejects edges with missing nodes", %{graph: graph} do
      edge = Edge.new("invalid", "alice", "bob", "KNOWS", %{})
      assert {:error, :node_not_found} = Graph.add_edge(graph, edge)
    end

    test "deletes nodes and cascades to edges", %{graph: graph} do
      node1 = Node.new("alice", ["Person"], %{name: "Alice"})
      node2 = Node.new("bob", ["Person"], %{name: "Bob"})

      {:ok, _graph} = Graph.add_node(graph, node1)
      {:ok, _graph} = Graph.add_node(graph, node2)

      edge = Edge.new("knows1", "alice", "bob", "KNOWS", %{})
      {:ok, _graph} = Graph.add_edge(graph, edge)

      # Delete node should succeed
      assert {:ok, _graph} = Graph.delete_node(graph, "alice")

      # Node should be gone
      assert {:error, :not_found} = Graph.get_node(graph, "alice")

      # Bob should still exist
      assert {:ok, _bob} = Graph.get_node(graph, "bob")
    end

    test "lists nodes with filters", %{graph: graph} do
      node1 = Node.new("alice", ["Person"], %{"name" => "Alice", "age" => 30})
      node2 = Node.new("bob", ["Person"], %{"name" => "Bob", "age" => 25})
      node3 = Node.new("company", ["Organization"], %{"name" => "ACME Corp"})

      {:ok, _graph} = Graph.add_node(graph, node1)
      {:ok, _graph} = Graph.add_node(graph, node2)
      {:ok, _graph} = Graph.add_node(graph, node3)

      # List all nodes
      all_nodes = Graph.list_nodes(graph)
      assert length(all_nodes) == 3

      # Filter by label
      people = Graph.list_nodes(graph, label: "Person")
      assert length(people) == 2

      # Filter by property
      alice_nodes = Graph.list_nodes(graph, property: {"name", "Alice"})
      assert length(alice_nodes) == 1
      assert hd(alice_nodes).id == "alice"
    end
  end

  describe "Graph traversal" do
    test "traverses connected nodes", %{graph: graph} do
      # Create a simple graph: alice -> bob -> charlie
      alice = Node.new("alice", ["Person"], %{name: "Alice"})
      bob = Node.new("bob", ["Person"], %{name: "Bob"})
      charlie = Node.new("charlie", ["Person"], %{name: "Charlie"})

      {:ok, _graph} = Graph.add_node(graph, alice)
      {:ok, _graph} = Graph.add_node(graph, bob)
      {:ok, _graph} = Graph.add_node(graph, charlie)

      edge1 = Edge.new("e1", "alice", "bob", "KNOWS", %{})
      edge2 = Edge.new("e2", "bob", "charlie", "KNOWS", %{})

      {:ok, _graph} = Graph.add_edge(graph, edge1)
      {:ok, _graph} = Graph.add_edge(graph, edge2)

      # Traverse from alice
      result = Query.traverse(graph, "alice", max_depth: 2)
      node_ids = Enum.map(result, & &1.id)

      assert "alice" in node_ids
      assert "bob" in node_ids
      assert "charlie" in node_ids
    end

    test "finds shortest path between nodes", %{graph: graph} do
      # Create a triangle: alice -> bob -> charlie -> alice
      alice = Node.new("alice", ["Person"], %{name: "Alice"})
      bob = Node.new("bob", ["Person"], %{name: "Bob"})
      charlie = Node.new("charlie", ["Person"], %{name: "Charlie"})

      {:ok, _graph} = Graph.add_node(graph, alice)
      {:ok, _graph} = Graph.add_node(graph, bob)
      {:ok, _graph} = Graph.add_node(graph, charlie)

      {:ok, _graph} = Graph.add_edge(graph, Edge.new("e1", "alice", "bob", "KNOWS", %{}))
      {:ok, _graph} = Graph.add_edge(graph, Edge.new("e2", "bob", "charlie", "KNOWS", %{}))
      {:ok, _graph} = Graph.add_edge(graph, Edge.new("e3", "charlie", "alice", "KNOWS", %{}))

      # Find path from alice to charlie
      assert {:ok, path} = Query.shortest_path(graph, "alice", "charlie")
      node_ids = Enum.map(path, & &1.id)

      # Should be either [alice, bob, charlie] or [alice, charlie] depending on direction
      assert "alice" == hd(node_ids)
      assert "charlie" == List.last(node_ids)
    end

    test "returns error when no path exists", %{graph: graph} do
      # Create two disconnected nodes
      alice = Node.new("alice", ["Person"], %{name: "Alice"})
      bob = Node.new("bob", ["Person"], %{name: "Bob"})

      {:ok, _graph} = Graph.add_node(graph, alice)
      {:ok, _graph} = Graph.add_node(graph, bob)

      assert {:error, :no_path} = Query.shortest_path(graph, "alice", "bob")
    end
  end
end
