# Partitioning

## When

Recommend partitioning only when at least one holds, and record the decision in an ADR:

- A table is expected to grow without bound (events, logs, ledger lines, metrics, messages) and queries almost always filter by one column (usually time).
- Data has a **retention** policy (delete after N months): dropping a partition replaces a huge `DELETE` + vacuum.
- Maintenance (vacuum, index rebuilds) on a single table has become too slow.

Not before: partitioning adds planning overhead, PK/FK restrictions and operational work. A table of a few million rows with good indexes doesn't need it. Rough signal: tens of millions of rows growing steadily, or a table larger than available RAM where most queries touch a recent slice.

## Types

| Type | When | Example |
|---|---|---|
| RANGE | Data ordered by time, amounts or sequences | One partition per month |
| LIST | Known, stable categories | Country, region, document type |
| HASH | Spread rows evenly when there's no natural order | By `customer_id` into 8 or 16 partitions |

## Rules

1. **Partition by the column that appears in most filters**, so the planner prunes partitions it doesn't need (partition pruning).
2. **Sustainable granularity.** Monthly is a good starting point for events and logs. Daily creates too many partitions over a long history; yearly can make each partition too big.
3. **Don't create too many partitions.** Hundreds are fine; many thousands, or sub-partitioning with multi-column keys, slow down planning and maintenance.
4. **Design for deletion.** Group data that expires together in the same partition; retention becomes `ALTER TABLE … DETACH PARTITION … CONCURRENTLY` + `DROP TABLE`.
5. **The partition key is part of every PK and UNIQUE constraint**: `PRIMARY KEY (id, created_at)`. FKs that point to a partitioned table must reference the full key, which is why partitioned tables are usually leaves (nobody references them) — keep it that way when possible.
6. **Create indexes for the queries, not for the key.** Pruning uses partition bounds, not indexes; indexes find rows inside each partition. Indexes created on the parent propagate to every partition.
7. **Keep conditions simple**: compare the partition key with constants or parameters using B-tree operators — equality for LIST, simple ranges for RANGE. Wrapping the key in a function (`date_trunc('month', created_at) = …`) defeats pruning.
8. **Always a DEFAULT partition** to catch rows outside the defined ranges, and monitor it: rows there mean partition creation is lagging.
9. **Automate future partitions**: create them ahead of time (e.g. 3 months) with `pg_partman`, a `pg_cron` job, or an external scheduled job. Never rely on someone remembering.

## Example (monthly RANGE)

```sql
-- 060-events.sql
-- Append-only product events, partitioned by month for retention (see ADR-003).
CREATE TABLE IF NOT EXISTS public.events (
  id          uuid        NOT NULL DEFAULT uuidv7(),
  tenant_id   uuid        NOT NULL,
  kind        text        NOT NULL,
  payload     jsonb       NOT NULL DEFAULT '{}',
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_events PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS public.events_default PARTITION OF public.events DEFAULT;
CREATE TABLE IF NOT EXISTS public.events_2026_11 PARTITION OF public.events
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');

CREATE INDEX IF NOT EXISTS idx_events_tenant_id_created_at ON public.events (tenant_id, created_at);
```

Creating the next partitions with `pg_cron` (function in `database/functions/`):

```sql
CREATE OR REPLACE FUNCTION public.create_event_partitions(p_months_ahead int DEFAULT 3)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_start date;
BEGIN
  FOR i IN 0..p_months_ahead LOOP
    v_start := date_trunc('month', now())::date + make_interval(months => i);
    EXECUTE format(
      'CREATE TABLE IF NOT EXISTS public.%I PARTITION OF public.events FOR VALUES FROM (%L) TO (%L)',
      'events_' || to_char(v_start, 'YYYY_MM'), v_start, v_start + interval '1 month');
  END LOOP;
END $$;
-- SELECT cron.schedule('create-event-partitions', '0 3 1 * *', 'SELECT public.create_event_partitions()');
```

Retention:

```sql
ALTER TABLE public.events DETACH PARTITION public.events_2025_10 CONCURRENTLY;  -- no-transaction migration or job
DROP TABLE public.events_2025_10;
```

Converting an existing large table to partitioned is an expand/contract operation (new partitioned table, dual-write or copy in batches, swap); plan it with an ADR.
