defmodule Semigraph.StorageTest do
  use ExUnit.Case, async: true

  alias Semigraph.{Storage, Node, Edge}

  setup do
    {:ok, storage} = Storage.new("test_storage_#{System.unique_integer()}")
    {:ok, storage: storage}
  end

  describe "Storage operations" do
    test "stores and retrieves nodes", %{storage: storage} do
      node = Node.new("test_node", ["Label"], %{prop: "value"})

      assert :ok = Storage.put_node(storage, node)
      assert {:ok, retrieved} = Storage.get_node(storage, "test_node")
      assert retrieved.id == "test_node"
    end

    test "stores and retrieves edges", %{storage: storage} do
      # Create nodes first
      node1 = Node.new("node1", [], %{})
      node2 = Node.new("node2", [], %{})

      Storage.put_node(storage, node1)
      Storage.put_node(storage, node2)

      edge = Edge.new("test_edge", "node1", "node2", "RELATES_TO", %{})

      assert :ok = Storage.put_edge(storage, edge)
      assert {:ok, retrieved} = Storage.get_edge(storage, "test_edge")
      assert retrieved.id == "test_edge"
    end

    test "queries nodes by labels", %{storage: storage} do
      node1 = Node.new("n1", ["Person"], %{})
      node2 = Node.new("n2", ["Person"], %{})
      node3 = Node.new("n3", ["Company"], %{})

      Storage.put_node(storage, node1)
      Storage.put_node(storage, node2)
      Storage.put_node(storage, node3)

      people = Storage.query_index(storage, :labels, "Person")
      assert length(people) == 2

      companies = Storage.query_index(storage, :labels, "Company")
      assert length(companies) == 1
    end

    test "queries nodes by properties", %{storage: storage} do
      node1 = Node.new("n1", [], %{"type" => "admin"})
      node2 = Node.new("n2", [], %{"type" => "user"})
      node3 = Node.new("n3", [], %{"type" => "admin"})

      Storage.put_node(storage, node1)
      Storage.put_node(storage, node2)
      Storage.put_node(storage, node3)

      admins = Storage.query_index(storage, :properties, {"type", "admin"})
      assert length(admins) == 2
    end

    test "gets edges for a node", %{storage: storage} do
      node1 = Node.new("n1", [], %{})
      node2 = Node.new("n2", [], %{})
      node3 = Node.new("n3", [], %{})

      Storage.put_node(storage, node1)
      Storage.put_node(storage, node2)
      Storage.put_node(storage, node3)

      edge1 = Edge.new("e1", "n1", "n2", "KNOWS", %{})
      edge2 = Edge.new("e2", "n3", "n1", "KNOWS", %{})

      Storage.put_edge(storage, edge1)
      Storage.put_edge(storage, edge2)

      edges = Storage.get_edges_for_node(storage, "n1")
      assert length(edges) == 2
    end

    test "deletes nodes and edges", %{storage: storage} do
      node = Node.new("test_node", ["Label"], %{prop: "value"})
      Storage.put_node(storage, node)

      assert :ok = Storage.delete_node(storage, "test_node")
      assert {:error, :not_found} = Storage.get_node(storage, "test_node")
    end
  end
end
