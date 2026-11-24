# ADR-001: stock_levels as a trigger-maintained aggregate of the stock ledger

- Status: Accepted
- Date: 2026-11-25

## Context

The source of truth for stock is the append-only `stock_movements` ledger. Answering "how much of item X is in warehouse Y" by summing the ledger gets slower as history grows, and enforcing "never below zero" on a sum requires locking and aggregating on every write.

## Decision

Keep `stock_levels (item_id, warehouse_id, quantity)` as a cached aggregate. It has a natural composite primary key (a derived table has no identity of its own), a `CHECK (quantity >= 0)`, and is written only by the `apply_stock_movement()` trigger. Consumers have read-only access.

## Alternatives considered

- Sum the ledger on every read: always correct, slow at scale, and the non-negative rule can't be a constraint.
- Materialized view: cheap to read, but stale between refreshes and can't enforce the rule at write time.
- Maintain levels in the application: every writer (scripts, jobs, other services) must remember to do it.

## Consequences

O(1) stock reads and a declarative non-negative rule. Trade-offs: one extra row write per movement, and hot rows for very active item/warehouse pairs (row lock contention under heavy concurrent issues of the same item).

## Consistency mechanism

`trg_stock_movements_apply` (AFTER INSERT) applies each movement inside the same transaction; the ledger is append-only (trigger + revoked privileges), so there are no updates or deletes to reverse. Reconciliation query for audits:

```sql
SELECT l.item_id, l.warehouse_id, l.quantity, coalesce(sum(m.quantity), 0) AS ledger
FROM public.stock_levels l
LEFT JOIN public.stock_movements m USING (item_id, warehouse_id)
GROUP BY 1, 2, 3
HAVING l.quantity <> coalesce(sum(m.quantity), 0);
```

## Review trigger

Contention on hot items (lock waits on `stock_levels` visible in `pg_stat_activity` / p95 of issue latency > 100 ms), or a need for reservations/valuation that changes what "level" means.

## Related

`public.stock_movements`, `public.stock_levels`, `public.apply_stock_movement()`, flows `purchase-order-receipt.md` and `stock-transfer.md`.
