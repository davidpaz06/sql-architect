# Migrations

Migrations are how an **existing** database changes. Sources of truth say what the schema *is*; migrations say how to get there from the previous state.

## Naming

```
MIG-<NNN>-<concept-in-kebab-case>-<YYYYMMDDHHmm>.sql
MIG-007-add-phone-to-users-202611251030.sql
```

- `NNN`: next number, unique and contiguous, at least three digits.
- Concept: what changes, in kebab-case, short.
- Timestamp suffix: creation time in **UTC**. It disambiguates migrations created in parallel branches. If two branches take the same number, whoever merges second renumbers (the build `check` fails on duplicates or gaps).

## File content

Start from `templates/migration.sql`:

1. Line 1: `-- <file name>`. Line 2 (and up to two more): **brief** explanation of what and why, linking the flow or ADR when there is one.
2. **Guard**: skip the whole file if its id is already in `schema_migrations`.
3. `BEGIN;` then `SET LOCAL ROLE <owner>` (new objects must belong to the owner whoever runs the file), `SET LOCAL lock_timeout`, `SET LOCAL statement_timeout`.
4. The change, with each statement idempotent (`IF NOT EXISTS`, `DO` blocks — see `idempotency-patterns.md`).
5. Self-registration: `INSERT INTO public.schema_migrations (id) VALUES ('<file name without .sql>') ON CONFLICT DO NOTHING;`
6. `COMMIT;`

**No commented rollback.** Later migrations may depend on this one, so reverting a single file in isolation can break the schema. To undo, write a new migration. A migration that has been merged is never edited.

### Statements that cannot run in a transaction

`CREATE INDEX CONCURRENTLY`, `DROP INDEX CONCURRENTLY`, `REINDEX CONCURRENTLY`, `VACUUM`, `ALTER TYPE … ADD VALUE` used in the same transaction. Put each in its **own** file from `templates/migration-no-transaction.sql`, which carries a `-- no-transaction` marker on line 3, has no `BEGIN/COMMIT`, and handles the INVALID index a failed concurrent build leaves behind.

## The `schema_migrations` table

```sql
CREATE TABLE IF NOT EXISTS public.schema_migrations (
  id          text        NOT NULL,              -- file name without .sql
  applied_at  timestamptz NOT NULL DEFAULT now(),
  applied_by  text        NOT NULL DEFAULT current_user,
  CONSTRAINT pk_schema_migrations PRIMARY KEY (id)
);
```

It is the model `database/models/000-schema-migrations.sql`. Bootstrap fills it with every existing migration (`applied_by = 'bootstrap'`); each migration inserts its own row.

What is applied:

```sql
SELECT id, applied_at, applied_by FROM public.schema_migrations ORDER BY id;
```

Applying pending migrations (each guard skips what is already applied):

```bash
<build> migrate                       # psql against $DATABASE_URL (use the owner role)
<build> migrate --docker              # inside the local compose service
# by hand:
for f in database/migrations/MIG-*.sql; do psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f "$f" || break; done
```

## The rule of three

A schema change is complete only when **one commit** contains:

1. The migration.
2. The sources of truth updated to describe the schema *after* the migration.
3. `bootstrap.sql` rebuilt (`<build> build`), with `<build> check` passing.

That is why migrations are not part of `bootstrap.sql` (only their ids, as the baseline): the sources already contain their effect. `drift-check.md` describes the CI test that proves both paths produce the same schema.

## Expand / contract

Use it for any change that would break consumers still running the old code: renames, type changes, splitting or merging columns or tables, adding `NOT NULL`, moving data.

| Phase | What happens | Consumers |
|---|---|---|
| **Expand** | Add the new structure alongside the old one, nullable/unenforced, without breaking anything. | Old code keeps working. New code writes **both** old and new (dual-write) or a trigger keeps them in sync. |
| **Migrate** | Backfill existing rows into the new structure, in batches. | Switch reads to the new structure. |
| **Contract** | In a **later** migration, once no consumer uses the old structure: enforce constraints on the new one and drop the old. | Old structure is gone. |

Example — rename `customers.phone_number` to `customers.phone` (bodies only; real files carry the header, guard and registration, and the `ADD CONSTRAINT` goes in a `DO` block):

```sql
-- MIG-010-expand-customers-phone-202611251100.sql
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS phone text;

-- MIG-011-backfill-customers-phone-202611251105.sql  (re-runnable; repeat until 0 rows)
UPDATE public.customers SET phone = phone_number
WHERE id IN (SELECT id FROM public.customers WHERE phone IS NULL AND phone_number IS NOT NULL LIMIT 10000);

-- … deploy consumers that read and write "phone" …

-- MIG-012-contract-customers-phone-202612021000.sql
ALTER TABLE public.customers ADD CONSTRAINT ck_customers_phone_not_null CHECK (phone IS NOT NULL) NOT VALID;
ALTER TABLE public.customers VALIDATE CONSTRAINT ck_customers_phone_not_null;
ALTER TABLE public.customers ALTER COLUMN phone SET NOT NULL;   -- uses the validated CHECK, no full scan under lock
ALTER TABLE public.customers DROP CONSTRAINT ck_customers_phone_not_null;
ALTER TABLE public.customers DROP COLUMN IF EXISTS phone_number;
```

Large backfills belong in a script or job that loops in batches with commits between them; a migration should not hold one transaction over millions of rows.

## Lock-safe DDL

- Always set `lock_timeout` (e.g. `5s`): a DDL waiting for a lock blocks every query queued behind it. Failing fast and retrying is better.
- Add foreign keys and checks as `NOT VALID`, then `VALIDATE CONSTRAINT` (validation takes a weaker lock).
- `SET NOT NULL` on a big table: validate a `CHECK (col IS NOT NULL)` first, as above.
- New indexes on big tables: `CREATE INDEX CONCURRENTLY` in a no-transaction migration.
- Avoid table rewrites: changing a column type (except some widening cases), adding a column with a volatile default, `ALTER TABLE … SET LOGGED/UNLOGGED`. Adding a column with a constant default does not rewrite.
- Unique constraint on a big table: `CREATE UNIQUE INDEX CONCURRENTLY`, then `ALTER TABLE … ADD CONSTRAINT … UNIQUE USING INDEX`.

## Never-deployed repos

Until a database exists anywhere other than throwaway locals, the team may edit sources directly and rebuild, without migrations. Agree on the moment this ends (first shared or production database), write `MIG-001` from then on, and note it in `contributing.md`.
