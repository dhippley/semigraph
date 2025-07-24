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

## 🧠 Performance Breakdown by Layer

| Layer                     | Performance Notes                                 | Bottlenecks                                         | Optimizations                                     |
| ------------------------- | ------------------------------------------------- | --------------------------------------------------- | ------------------------------------------------- |
| **Storage (ETS)**         | Fast, concurrent, lock-free, great for graph data | Not distributed, in-RAM only, slow with large scans | Keep graph normalized and use indexes             |
| **Algebra (Nx/EXLA)**     | Near-native matrix ops, can use GPU               | Dense matrices become expensive fast                | Use sparse matrices + semirings                   |
| **Query Engine (custom)** | Fast if simple traversal (BFS, DFS) or rule-based | No JIT/planner like Neo4j                           | Can precompile AST → op tree, use pattern caching |
| **Semiring Math**         | Flexible and expressive                           | User-defined ops may slow down                      | Compile-time specialization of common semirings   |
| **Parallelism**           | BEAM excels at concurrent graph ops               | Coordination costs for large graphs                 | Partition graph state across processes            |

---

## 🛠️ Performance Considerations in Elixir

- Use ETS smartly: maintain reverse indexes, partition by type, use compressed keys.
- Sparse matrices: especially for large graphs with few connections.
- Semiring pre-compilation: avoid dynamic dispatch in tight loops.
- Native Nx + EXLA: offload algebraic ops to TensorFlow/XLA.
- Supervised graph shards: keep node/edge buckets in GenServers for parallelism.
- Query caching: AST → op tree → result caching for repeat queries.

---

## 🧠 Roadmap

### Phase 1: Graph Engine MVP ✅
- [x] `Graph.new/0`, `add_node/2`, `add_edge/3`, `get_node/1`, `delete/1`
- [x] In-memory ETS-based storage
- [x] Basic label + property indexing
- [x] Simple path/query traversal

### Phase 2: Matrix Algebra Layer
- [x] Matrix representation (dense + sparse)
- [x] Matrix multiplication, transpose, dot product
- [x] Nx/EXLA backend for acceleration
- [x] Define custom `Semiring` structs
- [x] COO (Coordinate) format for sparse matrices
- [x] Bidirectional sparse ↔ dense conversion
- [x] Semiring-based matrix operations

#### 🔄 Phase 2 Future Optimizations
- [ ] **CSR Format**: For faster row operations
- [ ] **Native Sparse Multiplication**: Avoid dense conversion
- [ ] **Sparse Semiring Operations**: Direct sparse matrix algebra
- [ ] **Memory-Mapped Storage**: For very large sparse matrices

### Phase 3: Query Engine ⏳
- [x] Design Cypher-lite AST
- [x] Basic pattern matching queries (MATCH, RETURN, WHERE)
- [x] Graph query interpreter and basic DSL
- [ ] **Enhanced Edge Pattern Parsing** (3-week implementation)
  - [ ] **Phase 3.1**: Enhanced tokenization for compound edge patterns (`]-&gt;`, `&lt;-[`)
  - [ ] **Phase 3.2**: Refactored edge pattern parser with proper state management
  - [ ] **Phase 3.3**: Advanced pattern support (multi-edge, variable-length, properties)
- [ ] Query optimizer and execution planner
- [ ] Performance benchmarking and optimization

#### 🔄 Phase 3 Edge Pattern Parser Details
**Current Limitations**: Basic parser struggles with compound token sequences like `(a)-[:KNOWS]->(b)`

**Phase 3.1 - Enhanced Tokenization** (Week 1)
- [ ] Recognize compound edge patterns: `-[`, `]->`, `<-[`, `]-`
- [ ] Add new token types for edge sequences
- [ ] Improve `split_special_chars/1` for better token boundary detection

**Phase 3.2 - Refactored Parser** (Week 2)  
- [ ] Implement multi-step edge parsing with proper state management
- [ ] Add lookahead system for complex token sequences
- [ ] Support bidirectional edges: `(a)<-[:TYPE]->(b)`
- [ ] Enhanced error handling with position tracking

**Phase 3.3 - Advanced Patterns** (Week 3)
- [ ] Multiple edge chains: `(a)-[:KNOWS]->(b)-[:WORKS_AT]->(c)`
- [ ] Variable-length paths: `(a)-[:KNOWS*1..3]->(b)`
- [ ] Edge property filtering: `(a)-[:KNOWS {since: 2020}]->(b)`
- [ ] Optional patterns and path matching

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
3. ✅ Design matrix struct for Nx algebra (dense & sparse)
4. ✅ Implement basic semiring multiplication
5. ⏳ Write `MATCH` interpreter for simple patterns
6. ⏳ Benchmark traversal and algebra ops on toy graphs

---

## 📚 Inspirations
- RedisGraph
- GraphBLAS
- Neo4j
- Nx
- Erlang/ETS
