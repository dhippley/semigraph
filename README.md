# Semigraph

_A RedisGraph-inspired in-memory property graph engine built in Elixir._

Semigraph is a graph-native Elixir library designed for low-latency agent memory, planning, and queryable graph state — powered by ETS and Nx. It aims to combine the expressive modeling of RedisGraph with Elixir's concurrency and composability, with long-term goals of semiring-based algebra and Cypher-like queries.

---

## 🧱 Project Goals

- Build a **property graph engine** in Elixir (nodes, edges, props)
- Support **graph algebra** (via matrices and semirings)
- Enable **Cypher-lite querying** and DSLs for traversal and reasoning
- Stay fast and flexible using **ETS** and optionally **Nx** for algebraic ops

---

## 🔧 Core Approach

| Layer | Details |
|-------|---------|
| **Storage** | ETS-based, in-memory node/edge store with optional indexing |
| **Query Engine** | Pattern matching + traversal engine with Cypher-lite syntax |
| **Algebra Layer** | Matrix ops over sparse and dense graphs, backed by Nx |
| **Semirings** | Custom algebra kernels for pathfinding, logic graphs, scoring |
| **Elixir Native** | No C/NIF dependencies — pure Elixir + BEAM parallelism |

---

## 🧠 Roadmap

### Phase 1: Graph Engine MVP
- [ ] `Graph.new/0`, `add_node/2`, `add_edge/3`, `get_node/1`, `delete/1`
- [ ] In-memory ETS-based storage
- [ ] Basic label + property indexing
- [ ] Simple path/query traversal

### Phase 2: Matrix Algebra Layer
- [ ] Matrix representation (dense + sparse)
- [ ] Matrix multiplication, transpose, dot product
- [ ] Nx/EXLA backend for acceleration
- [ ] Define custom `Semiring` structs

### Phase 3: Query Engine
- [ ] Design Cypher-lite AST
- [ ] Pattern matching queries (MATCH, RETURN, WHERE)
- [ ] Graph query interpreter and optimizer
- [ ] Optional DSL fallback

### Phase 4: Agentic Extensions
- [ ] Graph-backed agent memory (episodic/semantic)
- [ ] Memory pruning and forgetting strategies
- [ ] Graph state diffing/versioning
- [ ] LLM planning support with goal decomposition over graphs

### Phase 5: Persistence + Scale
- [ ] DETS/SQLite serialization
- [ ] Partitioned graph memory (supervised shards)
- [ ] Live update hooks for graph events
- [ ] Optional Phoenix/PubSub for streaming updates

---

## ⚡ Performance Considerations

| Feature | Strength |
|--------|----------|
| ETS storage | Ultra-fast, lock-free, concurrent |
| Nx algebra | GPU/TPU backend support for algebra |
| Querying | Designed for low-latency agent use |
| Semirings | Customizable logic for reasoning and scoring |
| Elixir-native | Hot-reloadable, composable, no DB dependency |

### Where it shines:
- Agent memory / goal trees
- Planning, recommendation, traversal
- Lightweight knowledge graphs
- Embedded graph state in Elixir apps

---

## 🧪 Research & Design Notes

- ETS enables high-performance in-memory access, ideal for graph indexing.
- Nx + EXLA unlocks sparse matrix and semiring-based algebraic reasoning.
- GraphBLAS-inspired modeling gives a foundation for advanced query types.
- Elixir’s process model enables parallel exploration and memory modeling.
- Cypher-like queries will be interpreted, then optionally compiled to matrix ops.

---

## 🧭 Next Steps

1. ✅ Define `Node`, `Edge`, `Graph` structs
2. ✅ Scaffold ETS-backed `GraphDB.Storage` module
3. ⏳ Design matrix struct for Nx algebra (dense & sparse)
4. ⏳ Implement basic semiring multiplication
5. ⏳ Write `MATCH` interpreter for simple patterns
6. ⏳ Benchmark traversal and algebra ops on toy graphs

---

## 📦 Planned Modules

```elixir
Semigraph.Graph
Semigraph.Node
Semigraph.Edge
Semigraph.Storage   # ETS + indexing
Semigraph.Matrix    # Nx abstraction
Semigraph.Semiring  # Algebra kernels
Semigraph.Query     # Cypher-lite + DSL
Semigraph.Agent     # Optional agentic extensions
```
---

## 📚 Inspirations
- RedisGraph
- GraphBLAS
- Neo4j
- Nx
- Erlang/ETS
