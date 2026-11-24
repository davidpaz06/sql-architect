# Normalization and ADRs

## Normalize by default

Model to **third normal form (3NF)**:

- **1NF**: atomic values; no repeating groups (`phone1`, `phone2`, comma-separated lists) — use a child table or an array only when the values have no identity of their own.
- **2NF**: in composite keys, every non-key column depends on the whole key.
- **3NF**: no non-key column depends on another non-key column (store `customer_id`, not the customer's name, in `orders`).

Exceptions that are **not** denormalization: snapshots of values that must not change with the source (the unit price and product name on an invoice line, the address on a shipped order). They record history; document them in the table comment.

## Accepted denormalizations

Allowed when a real requirement (performance, flexibility) justifies the trade-off — and always recorded in an ADR:

| Technique | Use when | Cost |
|---|---|---|
| `jsonb` columns | Semi-structured attributes that vary per row and are rarely filtered (product attributes per category, integration payloads, settings) | Weak typing, constraints only via CHECK/jsonb schema checks; index with GIN when filtered |
| Counters / cached aggregates (`orders_count`, `balance`) | A hot read would otherwise aggregate many rows | Must be kept in sync (trigger, function, job) |
| Summary tables / materialized views | Dashboards and reports over large tables | Staleness; refresh strategy |
| Duplicated `tenant_id` on child tables | RLS and indexing per table | Composite FK keeps it consistent (see security.md) — this one is the default, no ADR needed |
| EAV (entity–attribute–value) | Truly user-defined fields with typed per-attribute validation, as a last resort | Very hard to query, validate and index. Usually an anti-pattern: prefer `jsonb` |

## ADR format

Location: `docs/adr/ADR-NNN-<decision-in-kebab-case>.md`, numbered sequentially. Template: `templates/adr.md`.

```
# ADR-001: <title>
- Status: Proposed | Accepted | Superseded by ADR-00X | Deprecated
- Date: YYYY-MM-DD
## Context
## Decision
## Alternatives considered
## Consequences            (benefits, trade-offs, debt)
## Consistency mechanism   (how redundant data is kept in sync, and who owns it)
## Review trigger          (metric or condition that reopens this decision)
## Related                 (tables, migrations, flows)
```

Write an ADR for: every denormalization, technical debt taken knowingly, deviations from this skill's defaults (key strategy, tenancy model, ENUM types, hard deletes on audited data), partitioning, and every scaling step. ADRs are never deleted: a changed decision gets a new ADR that supersedes the old one, and the old one's status is updated.

Point to the ADR from the affected table's `COMMENT ON TABLE` so readers of the schema find it.
