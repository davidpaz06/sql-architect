# Indexing

## Rules

1. **PRIMARY KEY and UNIQUE already create an index.** Don't duplicate them.
2. **Index foreign keys explicitly** unless proven useless. PostgreSQL does not index FK columns; without one, deleting a parent scans the child table and joins on the FK can't use an index. In tenant tables, the FK index usually becomes `(tenant_id, <fk>)`.
3. **Composite column order: equality first, then range/sort.** Lead with the columns that appear with `=` in most queries (in tenant tables, `tenant_id` first), then the column used for ranges or `ORDER BY`. A B-tree is only efficient on a leftmost prefix: an index on `(tenant_id, status, created_at)` serves `tenant_id = ? AND status = ? ORDER BY created_at` but not `status = ?` alone. Selectivity only breaks ties between equality columns.
4. **Prefer single-column indexes**; add composites for repeated query patterns. More than three key columns is rarely worth it. When a query reads only a couple of extra columns, `INCLUDE (…)` makes it an index-only scan without widening the key.
5. **Don't index low-selectivity columns** (`is_active`, `status` with 3 values) on their own. Use a **partial index** for the rare value you actually query: `CREATE INDEX … ON orders (created_at) WHERE status = 'pending';`. Soft delete: `WHERE deleted_at IS NULL`.
6. **Functions on the column disable a plain index.** `WHERE lower(email) = …` needs an expression index `ON users (lower(email))`, or a `citext` column.
7. **No speculative indexes in an MVP.** Every index costs writes, memory and vacuum. Justify each one with a real plan or `pg_stat_statements`, and drop unused ones.

## Index types

| Type | Use for |
|---|---|
| B-tree (default) | Equality, ranges, sorting, uniqueness |
| GIN | `jsonb` containment (`@>`), arrays, full-text (`tsvector`), trigram search (`gin_trgm_ops`) |
| GiST | Ranges and overlaps, geometry (PostGIS), exclusion constraints, nearest-neighbor |
| BRIN | Very large append-only tables physically ordered by time (logs, events, ledgers): tiny index, block-range pruning |
| HNSW (pgvector) | Approximate nearest neighbor on embeddings; better recall/latency than IVFFlat, no training step |
| Hash | Rarely; equality-only, B-tree is usually as good |

`jsonb_path_ops` GIN indexes are smaller and faster for `@>` only. Combine scalar + GIN columns in one index with `btree_gin`; scalar + range/exclusion with `btree_gist`.

## Validating

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT …;        -- real plan, timings, buffer hits/reads
```

Read it for: sequential scans on large tables under selective filters, row estimates far from actual (stale stats → `ANALYZE`), sorts spilling to disk, nested loops over many rows.

Find candidates and dead weight:

```sql
-- Most expensive statements (pg_stat_statements)
SELECT query, calls, mean_exec_time, total_exec_time
FROM extensions.pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20;

-- Indexes never used since stats reset
SELECT relname AS table, indexrelname AS index, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes WHERE idx_scan = 0 ORDER BY pg_relation_size(indexrelid) DESC;

-- FKs without a supporting index
SELECT c.conrelid::regclass AS table, c.conname
FROM pg_constraint c
WHERE c.contype = 'f'
  AND NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = c.conrelid
      AND (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] @> c.conkey
  );
```

(Unused-index results only mean something after representative traffic; check replicas too before dropping.)

## Building indexes on existing tables

On a table with traffic, `CREATE INDEX` blocks writes for the whole build. Use `CREATE INDEX CONCURRENTLY` in its own **no-transaction migration** (`templates/migration-no-transaction.sql`), which also handles the INVALID index a failed concurrent build leaves behind. In the model file the index stays as `CREATE INDEX IF NOT EXISTS` (bootstrap runs on empty tables).
