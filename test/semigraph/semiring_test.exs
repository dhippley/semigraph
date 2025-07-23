defmodule Semigraph.SemiringTest do
  use ExUnit.Case, async: true

  alias Semigraph.{Graph, Node, Edge, Matrix, Semiring}

  setup do
    {:ok, graph} = Graph.new("semiring_test_#{System.unique_integer()}")
    {:ok, graph: graph}
  end

  describe "Semiring definitions" do
    test "creates boolean semiring" do
      semiring = Semiring.boolean()

      assert semiring.name == "Boolean"
      assert semiring.zero == false
      assert semiring.one == true
      assert semiring.plus.(true, false) == true
      assert semiring.times.(true, false) == false
    end

    test "creates tropical semiring" do
      semiring = Semiring.tropical()

      assert semiring.name == "Tropical"
      assert semiring.zero == :infinity
      assert semiring.one == 0
      assert semiring.plus.(5, 3) == 3  # min
      assert semiring.times.(5, 3) == 8  # add
    end

    test "creates counting semiring" do
      semiring = Semiring.counting()

      assert semiring.name == "Counting"
      assert semiring.zero == 0
      assert semiring.one == 1
      assert semiring.plus.(5, 3) == 8
      assert semiring.times.(5, 3) == 15
    end

    test "creates probability semiring" do
      semiring = Semiring.probability()

      assert semiring.name == "Probability"
      assert semiring.zero == 0.0
      assert semiring.one == 1.0
      # a + b - a*b for probability union
      assert_in_delta semiring.plus.(0.3, 0.4), 0.58, 0.001
      assert semiring.times.(0.3, 0.4) == 0.12
    end

    test "creates custom semiring" do
      # Max-plus semiring
      semiring = Semiring.custom("MaxPlus", :neg_infinity, 0, &max/2, &+/2)

      assert semiring.name == "MaxPlus"
      assert semiring.zero == :neg_infinity
      assert semiring.one == 0
      assert semiring.plus.(5, 3) == 5  # max
      assert semiring.times.(5, 3) == 8  # add
    end
  end

  describe "Semiring operations" do
    test "applies semiring addition" do
      boolean = Semiring.boolean()
      result = Semiring.add(boolean, true, false)
      assert result == true
    end

    test "applies semiring multiplication" do
      tropical = Semiring.tropical()
      result = Semiring.multiply(tropical, 5, 3)
      assert result == 8
    end
  end

  describe "Matrix operations with semirings" do
    test "performs boolean matrix multiplication for reachability", %{graph: graph} do
      # Create a simple path: A -> B -> C
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

      # Create boolean adjacency matrix
      {:ok, matrix} = Matrix.from_graph(graph, :dense)

      # Convert to boolean values (1 -> true, 0 -> false)
      boolean_data = matrix.data
      |> Nx.greater_equal(1)

      boolean_matrix = %{matrix | data: boolean_data}

      # Test reachability via boolean semiring multiplication
      boolean_semiring = Semiring.boolean()

      # Matrix^2 should show 2-hop reachability (A can reach C in 2 steps)
      reachability2 = Matrix.semiring_power(boolean_matrix, 2, boolean_semiring)

      # Verify the result has proper structure
      assert reachability2.dimensions == {3, 3}
      assert reachability2.node_mapping == matrix.node_mapping
    end

    test "performs tropical matrix multiplication for shortest paths", %{graph: graph} do
      # Create a weighted graph
      a = Node.new("a", [], %{})
      b = Node.new("b", [], %{})
      c = Node.new("c", [], %{})

      {:ok, _graph} = Graph.add_node(graph, a)
      {:ok, _graph} = Graph.add_node(graph, b)
      {:ok, _graph} = Graph.add_node(graph, c)

      # Weighted edges for shortest path
      edge1 = Edge.new("e1", "a", "b", "CONNECTS", %{"weight" => 2})
      edge2 = Edge.new("e2", "b", "c", "CONNECTS", %{"weight" => 3})
      edge3 = Edge.new("e3", "a", "c", "CONNECTS", %{"weight" => 7})  # Longer direct path

      {:ok, _graph} = Graph.add_edge(graph, edge1)
      {:ok, _graph} = Graph.add_edge(graph, edge2)
      {:ok, _graph} = Graph.add_edge(graph, edge3)

      {:ok, matrix} = Matrix.from_graph(graph, :dense)

      # Replace 0s with infinity for tropical semiring
      tropical_data = matrix.data
      |> Nx.to_flat_list()
      |> Enum.map(fn
        0 -> :infinity
        val -> val
      end)
      |> Nx.tensor()
      |> Nx.reshape(Nx.shape(matrix.data))

      tropical_matrix = %{matrix | data: tropical_data}

      tropical_semiring = Semiring.tropical()

      # Matrix^2 should give shortest 2-hop paths
      shortest_paths2 = Matrix.semiring_power(tropical_matrix, 2, tropical_semiring)

      # Verify the result structure
      assert shortest_paths2.dimensions == {3, 3}
      assert shortest_paths2.node_mapping == matrix.node_mapping
    end

    test "performs counting matrix multiplication for path enumeration", %{graph: graph} do
      # Create a simple diamond graph for multiple paths
      a = Node.new("a", [], %{})
      b = Node.new("b", [], %{})
      c = Node.new("c", [], %{})
      d = Node.new("d", [], %{})

      {:ok, _graph} = Graph.add_node(graph, a)
      {:ok, _graph} = Graph.add_node(graph, b)
      {:ok, _graph} = Graph.add_node(graph, c)
      {:ok, _graph} = Graph.add_node(graph, d)

      # Create diamond: A -> B -> D, A -> C -> D
      edge1 = Edge.new("e1", "a", "b", "CONNECTS", %{})
      edge2 = Edge.new("e2", "a", "c", "CONNECTS", %{})
      edge3 = Edge.new("e3", "b", "d", "CONNECTS", %{})
      edge4 = Edge.new("e4", "c", "d", "CONNECTS", %{})

      {:ok, _graph} = Graph.add_edge(graph, edge1)
      {:ok, _graph} = Graph.add_edge(graph, edge2)
      {:ok, _graph} = Graph.add_edge(graph, edge3)
      {:ok, _graph} = Graph.add_edge(graph, edge4)

      {:ok, matrix} = Matrix.from_graph(graph, :dense)

      counting_semiring = Semiring.counting()

      # Matrix^2 should count 2-hop paths
      path_counts2 = Matrix.semiring_power(matrix, 2, counting_semiring)

      # Verify the result structure
      assert path_counts2.dimensions == {4, 4}
      assert path_counts2.node_mapping == matrix.node_mapping
    end
  end
end
