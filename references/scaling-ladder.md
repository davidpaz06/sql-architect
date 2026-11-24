# Scaling Ladder

Evaluate in order. Move up a level only when the level below has been exhausted **with evidence** (metrics, plans), and record each step taken as an ADR.

## Level 0 — Get the most out of one instance

Before any distribution:

- Query tuning and indexes (`indexing.md`), driven by `pg_stat_statements` and `EXPLAIN (ANALYZE, BUFFERS)`.
- **Connection pooling** (PgBouncer in transaction mode, or the provider's pooler). Many app instances × large pools exhaust memory long before CPU.
- Caching of hot, rarely-changing reads in the application or a cache layer.
- Archiving or partitioning cold data (`partitioning.md`); materialized views for heavy aggregates.
- Configuration (`shared_buffers`, `work_mem`, autovacuum tuning) and **vertical scaling**: a bigger instance is usually the cheapest step.

## Level 1 — Replication

| Question | If the answer is… | Usual solution |
|---|---|---|
| Can the database be down for minutes or hours? | No | Replication + automatic failover / high availability |
| Can you lose the most recent transactions if the primary fails? | No | Synchronous (or quorum/semi-synchronous) replication, accepting higher write latency |
| Do CPU, memory or I/O saturate because of reads? | Yes | Read replicas (route read-only traffic, tolerate replica lag) |
| Do heavy reports or analytics affect the primary? | Yes | A read replica or a separate analytics store |
| Do you need a copy in another region for disasters? | Yes | Cross-region replica / DR |
| Is the problem too much write volume? | Yes | Replication alone **does not** solve a write bottleneck: go to level 0 write optimizations, then level 2 |

Replicas add lag: consumers must know which reads tolerate stale data (read-your-own-writes goes to the primary).

## Level 2 — Sharding (fragmentation)

Split data across several primaries by a shard key (usually `tenant_id`). Each signal has a previous alternative that must be ruled out first:

| Signal | Key question | Previous alternative |
|---|---|---|
| Data volume | Does storage or the working set exceed what one instance handles cost-effectively? | Archiving, compression, partitioning |
| Saturated writes | Do transactions/writes per second exceed one primary's capacity? | Optimize writes, batching, queues, vertical scaling |
| Very concurrent queries | Does the system need more CPU/RAM/I/O than one instance offers? | Indexes, cache, read replicas |
| Geographic latency | Are users far from the database, or is data residency required? | Regional CDN/cache; geo-sharding if necessary |
| Fault isolation | Must a failure not affect every customer? | Replicas and HA; sharding reduces the blast radius |
| Vertical scaling limit | Have bigger instances, indexes, partitions and replicas all been tried without solving the bottleneck? | Re-evaluate the architecture |

The shared-schema + `tenant_id` model is shard-ready: every tenant table already carries the shard key and queries already filter by it. Cross-shard queries, global uniqueness and rebalancing are the costs — uuidv7 keys avoid id collisions across shards.

## Level 3 — Distributed SQL or specialized engines

When a sharded primary set is still not enough, or the workload changes nature:

- **Multi-region writes** or throughput beyond manual sharding: distributed PostgreSQL (Citus) or distributed SQL engines (CockroachDB, YugabyteDB). Expect differences in isolation, latency and feature support; prototype first.
- **Heavy analytics**: a columnar engine fed by replication/CDC (ClickHouse, a warehouse) instead of running analytics on the OLTP database.
- **Specialized workloads**: search engines for complex full-text/relevance, time-series engines for very high-rate metrics.

Recommending level 3 for an MVP is almost always premature; say so and point at the level-0 steps that come first.

## Capacity estimate (used by `audit`)

For each large table: current rows, growth per month, average row size (`pg_relation_size / reltuples`), index size. Project 12–24 months and compare total data + indexes against RAM and storage of the target instance. The level where the projection first breaks is the recommendation.
