defmodule Semigraph do
  @moduledoc """
  A RedisGraph-inspired in-memory property graph engine built in Elixir.

  Semigraph provides a high-performance, ETS-backed graph database with
  support for property graphs, matrix algebra operations, and custom
  query DSLs optimized for agent memory and planning use cases.

  ## Quick Start

      # Create a new graph
      {:ok, graph} = Semigraph.Graph.new("my_graph")

      # Add nodes and edges
      node1 = Semigraph.Node.new("alice", ["Person"], %{name: "Alice", age: 30})
      node2 = Semigraph.Node.new("bob", ["Person"], %{name: "Bob", age: 25})
      edge = Semigraph.Edge.new("knows", "alice", "bob", "KNOWS", %{since: 2020})

      # Query the graph
      results = Semigraph.Query.run(graph, "MATCH (n:Person) RETURN n")

  ## Architecture

  - **Storage Layer**: ETS-based concurrent storage with indexing
  - **Matrix Layer**: Nx-powered sparse/dense matrix operations
  - **Query Engine**: Custom DSL with Cypher-inspired syntax
  - **Semiring Algebra**: Customizable algebraic operations
  - **Agent Extensions**: Specialized memory and planning operations
  """

  alias Semigraph.{Graph, Node, Edge, Query, Storage, Matrix, Semiring, Agent}

  # Convenience delegations to main modules
  defdelegate new_graph(name, opts \\ []), to: Graph, as: :new
  defdelegate new_node(id, labels \\ [], properties \\ %{}), to: Node, as: :new
  defdelegate new_edge(id, from, to, type, properties \\ %{}), to: Edge, as: :new
  defdelegate query(graph, query_string), to: Query, as: :run
end
