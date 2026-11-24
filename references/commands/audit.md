# audit

Full audit of the data model. Scope: the whole repo by default, or what the user names (a schema, some tables, specific queries).

## Inputs

- The sources of truth (always).
- If a database is reachable (local container or a URL the user provides): catalog queries, `pg_stat_statements`, `pg_stat_user_tables/indexes`, table sizes. Ask before connecting to anything that isn't local, and run **read-only** queries only.
- Queries or plans the user provides; expected growth numbers if they have them (ask once; estimate and label as estimates otherwise).

## Procedure

1. **Structure and process.** Run the build `check`. Verify migrations ↔ sources consistency (drift test if possible). Flag repo anti-patterns.
2. **Normal forms.** For each table: 1NF (atomic columns, no repeating groups), 2NF (composite keys), 3NF (transitive dependencies). Distinguish legitimate snapshots (invoice lines) from real denormalization.
3. **Denormalizations.** List every one found (JSONB with core fields, counters, duplicated columns, summary tables, EAV). For each: is there an ADR? Does it define a consistency mechanism and does that mechanism exist in the code? Propose ADRs for those missing (draft them with the `adr` template, don't write without confirmation).
4. **Conventions.** Naming, types (`timestamptz`, `numeric` money, `text`), `NOT NULL`, named constraints, `ON DELETE`, keys (uuidv7 / identity), audit columns and triggers, headers.
5. **Security.** RLS (`ENABLE`, `FORCE`, `USING` + `WITH CHECK`) on every tenant table, composite tenant FKs, roles/grants/default privileges, `SECURITY DEFINER` hygiene, secrets in files.
6. **Indexes.** FKs without index, wrong composite order, duplicates/redundant prefixes, low-selectivity indexes, unused ones (with stats), missing partial/expression indexes for known queries.
7. **Specific queries.** For each query given (or the top of `pg_stat_statements`): `EXPLAIN (ANALYZE, BUFFERS)` on a non-production database or the plan provided; diagnose and propose index/rewrite (`explain` procedure).
8. **Performance estimate.** Per large table: rows, growth/month, average row size, index size; project 12–24 months against the instance's RAM and storage (`references/scaling-ladder.md`, capacity estimate). Identify partitioning candidates.
9. **Scaling level.** Conclude which level of the ladder the system is at and whether any action is warranted now, with the trigger that would justify the next level.

## Report

```
# Database audit — <project> — YYYY-MM-DD
## Summary            (3–5 lines: overall state, top risks, recommended scaling level)
## Findings           table: severity (critical/high/medium/low) | area | finding | evidence | fix
## Denormalizations   table: item | ADR | consistency mechanism | status
## Queries            per query: plan summary, diagnosis, proposal
## Capacity           table: table | rows | growth/mo | size now | size in 12/24 mo
## Scaling            current level, actions now, trigger for next level
## Proposed changes   migrations/ADRs to create, in order
```

Severity: *critical* = data leak or loss possible (RLS gaps, missing FKs on money, secrets); *high* = correctness or outage risk; *medium* = performance/maintainability; *low* = convention.

Show the report in the conversation and offer to save it as `docs/audits/audit-YYYYMMDD.md`. Don't change any file during the audit; fixes go through `migrate`/`adr` afterwards.
