# explain

Analyze a query or an execution plan and propose improvements.

1. Get the evidence. If given a query and a non-production database is reachable, run `EXPLAIN (ANALYZE, BUFFERS, SETTINGS)` (wrap data-modifying statements in `BEGIN … ROLLBACK`). If given a plan, use it. If neither is possible, analyze statically and say the result is unverified.
2. Read the plan bottom-up and report: the most expensive node, estimated vs actual rows (misestimates → stale stats or correlated columns → `ANALYZE`, extended statistics), scan types, sorts or hashes spilling to disk, loops multiplying cost, buffers read vs hit.
3. Map the query to `references/indexing.md`: equality-then-range column order, partial/expression/covering indexes, index type, tenant-leading indexes under RLS (policies add `tenant_id = …` to every query).
4. Propose, in order of preference: query rewrite (sargable predicates, avoiding functions on columns, `EXISTS` vs `IN`, keyset pagination instead of large `OFFSET`), index, statistics, schema change. For each, the expected effect and its write cost.
5. If an index is chosen, deliver it as a no-transaction migration with `CREATE INDEX CONCURRENTLY` plus the model update, through the `migrate` procedure (confirm first).
6. When possible, re-run `EXPLAIN` with the change on the test database and show before/after.
