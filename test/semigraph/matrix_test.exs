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

  describe "Sparse matrix operations" do
    test "creates sparse adjacency matrix from graph", %{graph: graph} do
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

      # Create sparse matrix
      {:ok, matrix} = Matrix.from_graph(graph, :sparse)

      assert matrix.type == :sparse
      assert map_size(matrix.node_mapping) == 3
      assert matrix.dimensions == {3, 3}

      # Check sparse structure
      assert is_map(matrix.data)
      assert Map.has_key?(matrix.data, :indices)
      assert Map.has_key?(matrix.data, :values)
      assert Map.has_key?(matrix.data, :shape)

      # Check that we can extract edges back
      edges = Matrix.to_edges(matrix)
      assert length(edges) == 2
    end

    test "converts between sparse and dense representations", %{graph: graph} do
      # Create simple graph
      alice = Node.new("alice", [], %{})
      bob = Node.new("bob", [], %{})

      {:ok, _graph} = Graph.add_node(graph, alice)
      {:ok, _graph} = Graph.add_node(graph, bob)

      edge = Edge.new("e1", "alice", "bob", "KNOWS", %{"weight" => 3.0})
      {:ok, _graph} = Graph.add_edge(graph, edge)

      # Start with dense
      {:ok, dense_matrix} = Matrix.from_graph(graph, :dense)

      # Convert to sparse
      sparse_matrix = Matrix.convert(dense_matrix, :sparse)
      assert sparse_matrix.type == :sparse
      assert sparse_matrix.dimensions == dense_matrix.dimensions
      assert sparse_matrix.node_mapping == dense_matrix.node_mapping

      # Convert back to dense
      dense_again = Matrix.convert(sparse_matrix, :dense)
      assert dense_again.type == :dense
      assert dense_again.dimensions == sparse_matrix.dimensions
      assert dense_again.node_mapping == sparse_matrix.node_mapping

      # Check that edges are preserved through conversions
      original_edges = Matrix.to_edges(dense_matrix) |> Enum.sort()
      sparse_edges = Matrix.to_edges(sparse_matrix) |> Enum.sort()
      final_edges = Matrix.to_edges(dense_again) |> Enum.sort()

      assert original_edges == sparse_edges
      assert sparse_edges == final_edges
    end

    test "handles empty sparse matrix", %{graph: graph} do
      {:ok, matrix} = Matrix.from_graph(graph, :sparse)

      assert matrix.type == :sparse
      assert matrix.dimensions == {0, 0}
      assert matrix.node_mapping == %{}
      assert matrix.data == nil

      # Can convert empty sparse to dense
      dense_matrix = Matrix.convert(matrix, :dense)
      assert dense_matrix.type == :dense
      assert dense_matrix.dimensions == {0, 0}
    end

    test "sparse matrix multiplication", %{graph: graph} do
      # Create simple path graph: a -> b -> c
      a = Node.new("a", [], %{})
      b = Node.new("b", [], %{})
      c = Node.new("c", [], %{})

      {:ok, _graph} = Graph.add_node(graph, a)
      {:ok, _graph} = Graph.add_node(graph, b)
      {:ok, _graph} = Graph.add_node(graph, c)

      edge1 = Edge.new("e1", "a", "b", "CONNECTS", %{})
      edge2 = Edge.new("e2", "b", "c", "CONNECTS", %{})

      {:ok, _graph} = Graph.add_edge(graph, edge1)
      {:ok, _graph} = Graph.add_edge(graph, edge2)

      {:ok, sparse_matrix} = Matrix.from_graph(graph, :sparse)

      # Test sparse matrix self-multiplication
      result = Matrix.multiply(sparse_matrix, sparse_matrix)

      assert result.type == :sparse
      assert result.dimensions == {3, 3}
      assert result.node_mapping == sparse_matrix.node_mapping

      # A^2 should show 2-hop connections (a can reach c in 2 hops)
      edges = Matrix.to_edges(result)

      # Should have at least the 2-hop path from a to c
      assert Enum.any?(edges, fn {from, to, _weight} -> from == "a" && to == "c" end)
    end

    test "sparse matrix with weighted edges", %{graph: graph} do
      # Create weighted sparse matrix
      alice = Node.new("alice", [], %{})
      bob = Node.new("bob", [], %{})
      charlie = Node.new("charlie", [], %{})

      {:ok, _graph} = Graph.add_node(graph, alice)
      {:ok, _graph} = Graph.add_node(graph, bob)
      {:ok, _graph} = Graph.add_node(graph, charlie)

      # Different weights
      edge1 = Edge.new("e1", "alice", "bob", "KNOWS", %{"weight" => 1.5})
      edge2 = Edge.new("e2", "bob", "charlie", "KNOWS", %{"weight" => 2.5})
      edge3 = Edge.new("e3", "alice", "charlie", "KNOWS", %{"weight" => 0.5})

      {:ok, _graph} = Graph.add_edge(graph, edge1)
      {:ok, _graph} = Graph.add_edge(graph, edge2)
      {:ok, _graph} = Graph.add_edge(graph, edge3)

      {:ok, sparse_matrix} = Matrix.from_graph(graph, :sparse)

      # Extract edges and verify weights are preserved
      edges = Matrix.to_edges(sparse_matrix)
      assert length(edges) == 3

      # Check specific weights
      weights_map = Enum.into(edges, %{}, fn {from, to, weight} -> {{from, to}, weight} end)
      assert weights_map[{"alice", "bob"}] == 1.5
      assert weights_map[{"bob", "charlie"}] == 2.5
      assert weights_map[{"alice", "charlie"}] == 0.5
    end
  end
end
