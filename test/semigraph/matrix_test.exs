defmodule Semigraph.MatrixTest do
  use ExUnit.Case, async: true

  alias Semigraph.{Graph, Node, Edge, Matrix}

  setup do
    {:ok, graph} = Graph.new("matrix_test_#{System.unique_integer()}")
    {:ok, graph: graph}
  end

  describe "Matrix operations" do
    test "creates adjacency matrix from graph", %{graph: graph} do
      # Create a simple graph: alice -> bob -> charlie
      alice = Node.new("alice", ["Person"], %{"name" => "Alice"})
      bob = Node.new("bob", ["Person"], %{"name" => "Bob"})
      charlie = Node.new("charlie", ["Person"], %{"name" => "Charlie"})

      {:ok, _graph} = Graph.add_node(graph, alice)
      {:ok, _graph} = Graph.add_node(graph, bob)
      {:ok, _graph} = Graph.add_node(graph, charlie)

      edge1 = Edge.new("e1", "alice", "bob", "KNOWS", %{})
      edge2 = Edge.new("e2", "bob", "charlie", "KNOWS", %{})

      {:ok, _graph} = Graph.add_edge(graph, edge1)
      {:ok, _graph} = Graph.add_edge(graph, edge2)

      # Create matrix
      {:ok, matrix} = Matrix.from_graph(graph, :dense)

      assert matrix.type == :dense
      assert map_size(matrix.node_mapping) == 3
      assert matrix.dimensions == {3, 3}

      # Check that we can extract edges back
      edges = Matrix.to_edges(matrix)
      assert length(edges) == 2
    end

    test "handles empty graph", %{graph: graph} do
      {:ok, matrix} = Matrix.from_graph(graph, :dense)

      assert matrix.dimensions == {0, 0}
      assert matrix.node_mapping == %{}
    end

    test "transposes matrix", %{graph: graph} do
      # Create simple directed graph
      alice = Node.new("alice", [], %{})
      bob = Node.new("bob", [], %{})

      {:ok, _graph} = Graph.add_node(graph, alice)
      {:ok, _graph} = Graph.add_node(graph, bob)

      edge = Edge.new("e1", "alice", "bob", "KNOWS", %{})
      {:ok, _graph} = Graph.add_edge(graph, edge)

      {:ok, matrix} = Matrix.from_graph(graph, :dense)
      transposed = Matrix.transpose(matrix)

      assert transposed.dimensions == matrix.dimensions
      assert transposed.type == matrix.type
    end

    test "multiplies compatible matrices", %{graph: graph} do
      # Create simple graph
      alice = Node.new("alice", [], %{})
      bob = Node.new("bob", [], %{})

      {:ok, _graph} = Graph.add_node(graph, alice)
      {:ok, _graph} = Graph.add_node(graph, bob)

      edge = Edge.new("e1", "alice", "bob", "KNOWS", %{})
      {:ok, _graph} = Graph.add_edge(graph, edge)

      {:ok, matrix} = Matrix.from_graph(graph, :dense)

      # Matrix multiplication with itself (for paths of length 2)
      result = Matrix.multiply(matrix, matrix)

      assert result.dimensions == matrix.dimensions
      assert result.node_mapping == matrix.node_mapping
    end

    test "computes matrix powers", %{graph: graph} do
      # Create simple graph
      alice = Node.new("alice", [], %{})
      bob = Node.new("bob", [], %{})

      {:ok, _graph} = Graph.add_node(graph, alice)
      {:ok, _graph} = Graph.add_node(graph, bob)

      edge = Edge.new("e1", "alice", "bob", "KNOWS", %{})
      {:ok, _graph} = Graph.add_edge(graph, edge)

      {:ok, matrix} = Matrix.from_graph(graph, :dense)

      # Power of 1 should return the same matrix
      power1 = Matrix.power(matrix, 1)
      assert power1.data == matrix.data

      # Power of 2 should be equivalent to matrix multiplication
      power2 = Matrix.power(matrix, 2)
      expected = Matrix.multiply(matrix, matrix)
      assert power2.data == expected.data
    end

    test "converts matrix types", %{graph: graph} do
      # Create simple graph
      alice = Node.new("alice", [], %{})
      bob = Node.new("bob", [], %{})

      {:ok, _graph} = Graph.add_node(graph, alice)
      {:ok, _graph} = Graph.add_node(graph, bob)

      edge = Edge.new("e1", "alice", "bob", "KNOWS", %{})
      {:ok, _graph} = Graph.add_edge(graph, edge)

      {:ok, dense_matrix} = Matrix.from_graph(graph, :dense)
      sparse_matrix = Matrix.convert(dense_matrix, :sparse)

      assert sparse_matrix.type == :sparse
      assert sparse_matrix.dimensions == dense_matrix.dimensions
      assert sparse_matrix.node_mapping == dense_matrix.node_mapping
    end

    test "handles weighted edges", %{graph: graph} do
      # Create graph with weighted edge
      alice = Node.new("alice", [], %{})
      bob = Node.new("bob", [], %{})

      {:ok, _graph} = Graph.add_node(graph, alice)
      {:ok, _graph} = Graph.add_node(graph, bob)

      # Edge with weight property
      edge = Edge.new("e1", "alice", "bob", "KNOWS", %{"weight" => 2.5})
      {:ok, _graph} = Graph.add_edge(graph, edge)

      {:ok, matrix} = Matrix.from_graph(graph, :dense)
      edges = Matrix.to_edges(matrix)

      assert length(edges) == 1
      {from, to, weight} = hd(edges)
      assert from == "alice"
      assert to == "bob"
      assert weight == 2.5
    end
  end
end
