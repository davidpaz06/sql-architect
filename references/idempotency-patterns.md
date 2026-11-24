# Idempotency Patterns (PostgreSQL 18)

Every source file and every migration must be safe to run twice. Use the native form when PostgreSQL has one; otherwise a `DO` block that checks the catalog first.

| Object | Pattern |
|---|---|
| Extension | `CREATE EXTENSION IF NOT EXISTS x WITH SCHEMA extensions;` |
| Schema | `CREATE SCHEMA IF NOT EXISTS s AUTHORIZATION owner;` |
| Table | `CREATE TABLE IF NOT EXISTS …` (constraints inline) |
| Column (migration) | `ALTER TABLE t ADD COLUMN IF NOT EXISTS c …;` / `DROP COLUMN IF EXISTS` |
| Index | `CREATE INDEX IF NOT EXISTS …` / `CREATE UNIQUE INDEX IF NOT EXISTS …` |
| Function / procedure | `CREATE OR REPLACE FUNCTION …` (signature changes need `DROP FUNCTION IF EXISTS old_signature` first) |
| View | `CREATE OR REPLACE VIEW …` (only adding columns at the end; otherwise drop + create) |
| Materialized view | `CREATE MATERIALIZED VIEW IF NOT EXISTS …` |
| Trigger | `CREATE OR REPLACE TRIGGER …` |
| Role, type, domain, policy, constraint added later | `DO` block with a catalog check |
| Role with password | `SELECT format(…, :'pwd') WHERE NOT EXISTS (…) \gexec` |
| Grants / revokes / default privileges | Already idempotent |
| `COMMENT ON` | Already idempotent |
| `ALTER TABLE … ENABLE / FORCE ROW LEVEL SECURITY` | Already idempotent |
| Seed rows | `INSERT … ON CONFLICT (key) DO NOTHING` or `DO UPDATE SET …` |

## DO-block templates

```sql
-- Type / enum (prefer text + CHECK or a catalog table; see keys-and-types.md)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE n.nspname = 'public' AND t.typname = 'money_amount') THEN
    CREATE DOMAIN public.money_amount AS numeric(14,2) CHECK (VALUE >= 0);
  END IF;
END $$;

-- Policy
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE schemaname = 'public' AND tablename = 'projects' AND policyname = 'tenant_isolation') THEN
    CREATE POLICY tenant_isolation ON public.projects
      USING (tenant_id = public.current_tenant_id())
      WITH CHECK (tenant_id = public.current_tenant_id());
  END IF;
END $$;

-- Constraint added after the table exists (circular FKs, migrations)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                 WHERE conrelid = 'public.users'::regclass AND conname = 'fk_users_default_team_id') THEN
    ALTER TABLE public.users
      ADD CONSTRAINT fk_users_default_team_id FOREIGN KEY (default_team_id)
      REFERENCES public.teams (id) ON DELETE SET NULL NOT VALID;
  END IF;
END $$;
ALTER TABLE public.users VALIDATE CONSTRAINT fk_users_default_team_id;  -- idempotent
```

## Seeds

```sql
-- Catalog with identity key: seed the natural key, never the generated id
INSERT INTO public.currencies (code, name, minor_units) VALUES
  ('EUR', 'Euro', 2),
  ('USD', 'US Dollar', 2)
ON CONFLICT (code) DO NOTHING;
```

Use `DO UPDATE SET` only when the source of truth must win over manual changes (e.g. labels); `DO NOTHING` is the safer default.

## Migrations: whole-file guard

On top of statement-level idempotency, every migration starts with a guard that skips the file when its id is already in `schema_migrations` (see `templates/migration.sql`). The guard makes re-runs cheap and avoids re-executing data backfills; the statement-level patterns protect against partially-applied manual runs.

## Things that are not idempotent by nature

- `ALTER TABLE … RENAME` — check the catalog first, or prefer expand/contract.
- `ALTER TYPE … ADD VALUE` — use `ADD VALUE IF NOT EXISTS`; it cannot be used in the same transaction that then uses the new value.
- Data backfills — write them as `UPDATE … WHERE new_col IS NULL` so a re-run only touches remaining rows.
- `INSERT` without a unique key — add a natural key or use `WHERE NOT EXISTS`.
