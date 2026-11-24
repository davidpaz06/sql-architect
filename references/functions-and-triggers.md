# Functions, Procedures and Triggers

## Functions

**What a function is and isn't.** A PostgreSQL function does not open its own transaction: it runs inside the caller's. The value of putting a multi-write operation in a function is:

- **One round trip** for an operation that needs several reads and writes.
- **Invariants next to the data**: checks and writes happen with the right row locks (`SELECT … FOR UPDATE`) in a single place, whatever consumer calls it.
- **Controlled privileges**: with `SECURITY DEFINER`, consumers get `EXECUTE` on the function without direct `INSERT/UPDATE` on the underlying tables (ledgers, balances).

Use a function when an operation needs verification plus several writes that must succeed or fail together **and** the rule is a critical invariant of the data — posting a balanced journal entry, reserving stock without overselling, transferring between accounts. Keep general business logic (workflows, notifications, pricing rules that change weekly) in the application. Document each function in the flow it implements.

### Template

```sql
-- post-journal-entry.sql
-- Posts a balanced journal entry atomically; rejects unbalanced or empty entries.
CREATE OR REPLACE FUNCTION public.post_journal_entry(
  p_entry_on   date,
  p_memo       text,
  p_lines      jsonb            -- [{"account_id": "...", "debit": 10.00, "credit": 0}]
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_entry_id uuid;
BEGIN
  IF jsonb_array_length(p_lines) < 2 THEN
    RAISE EXCEPTION 'journal entry needs at least two lines' USING ERRCODE = 'AP201';
  END IF;
  -- …
  RETURN v_entry_id;
END
$$;

REVOKE EXECUTE ON FUNCTION public.post_journal_entry(date, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.post_journal_entry(date, text, jsonb) TO app_rw;
```

### `SECURITY DEFINER` checklist

- `SET search_path = pg_catalog, public` (or the exact schemas) on the function — otherwise a caller can shadow tables or operators with objects in a schema they control.
- Schema-qualify every table and function inside the body.
- `REVOKE EXECUTE … FROM PUBLIC`, then grant to the groups that need it.
- The function runs as its owner (which bypasses RLS if the owner has `BYPASSRLS`): tenant-scoped definer functions must filter by `public.current_tenant_id()` themselves.
- Keep it narrow: one operation per function.

Prefer `SECURITY INVOKER` (the default) when consumers already have the table privileges and RLS should apply normally.

### Procedures

Use `CREATE PROCEDURE` only when you need transaction control inside the routine (`COMMIT` between batches in a long maintenance job), or another concrete, documented advantage. Procedures can't be called from a query and can't return a result set like a function; for normal operations a function is the better tool.

## Error contract (SQLSTATE)

Business errors raised by functions use a **project SQLSTATE class** so consumers can map them without parsing messages:

- Class `AP` (application), codes `AP000`–`APZZZ`. PostgreSQL's own classes are digit-led or the reserved letter classes (`F0`, `HV`, `P0`, `XX`); none starts with `AP`.
- Reserve `AP0xx` for generic/infrastructure errors (`AP001` = mutation of an append-only table), and blocks of 100 per area: `AP1xx` orders, `AP2xx` accounting, etc.
- Raise with `RAISE EXCEPTION '<message>' USING ERRCODE = 'AP2xx', DETAIL = '…', HINT = '…';`
- List every code in the flow doc of the function and in `docs/flows/README` or the integration contract.

Constraint violations keep PostgreSQL's standard codes (`23505` unique, `23503` FK, `23514` check, `23P01` exclusion); consumers map those too, so name constraints meaningfully.

## Triggers

Use triggers only for:

1. **`updated_at` maintenance** — `set_updated_at()`, one shared function.
2. **Internal operations coupled to another write**: audit rows, inserting into an immutable ledger as a consequence of a status change, keeping a derived/denormalized value reconciled (documented in its ADR's consistency mechanism).
3. **Enforcing immutability** — `prevent_mutation()` on append-only tables.

Never for business flows (sending emails, creating orders, chaining processes): they hide behavior from readers, run once per row, and make failures hard to trace. If a trigger needs more than a few lines of logic, it probably belongs in a function called explicitly.

Rules:
- `CREATE OR REPLACE TRIGGER trg_<table>_<purpose>`.
- One file per purpose in `database/triggers/` (e.g. `updated-at.sql` attaches `set_updated_at` to every mutable table).
- Prefer `FOR EACH ROW … WHEN (…)` conditions over branching inside the function.
- Statement-level triggers with transition tables (`REFERENCING NEW TABLE AS …`) for bulk audit.

## Pitfalls found in practice

- **`INSERT … ON CONFLICT DO UPDATE` checks CHECK constraints on the proposed row before resolving the conflict.** An upsert that adds a negative delta to a counter with `CHECK (quantity >= 0)` fails even when the existing row has enough. Do `UPDATE` first and `INSERT … ON CONFLICT` only `IF NOT FOUND` (see `inventory-erp/database/functions/apply-stock-movement.sql`).
- **`SELECT … FOR UPDATE` needs `UPDATE` privilege.** A `SECURITY INVOKER` function that locks rows of a read-only table fails for consumers; make it `SECURITY DEFINER` (with the checklist above) or lock a row the caller may update.
- **`WITH ORDINALITY` and a column definition list don't mix** for `jsonb_to_recordset`: use `ROWS FROM (jsonb_to_recordset(x) AS (a uuid, b numeric)) WITH ORDINALITY AS t(a, b, ord)`.
- **Trigger functions run with the privileges of the user firing them**, unless `SECURITY DEFINER`. A trigger that maintains a table consumers can't write must be a definer.
- **`RETURNS TABLE (col …)` creates PL/pgSQL variables** with those names: qualify every column reference in the body (`t.tenant_id`) to avoid "column reference is ambiguous".
- **Temporary tables in definer functions** are created as the owner and live in the caller's session; avoid them — use CTEs or repeat the `jsonb_to_recordset` scan.
