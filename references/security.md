# Security: RLS and DCL

## Multi-tenancy models

| Model | Isolation | Cost | Use when |
|---|---|---|---|
| **Shared schema + `tenant_id` + RLS** (default) | Row level, enforced by the database | Lowest; one schema to migrate | Most SaaS MVPs, many small tenants |
| Schema per tenant | Namespace | Migrations × tenants; catalog bloat past a few thousand schemas | Few large tenants with custom extensions |
| Database per tenant | Full | Highest; connection pools × tenants | Regulatory isolation, per-tenant backup/restore, very large tenants |

Anything other than the default is an ADR. The isolation column is `tenant_id` unless the user chooses another (sub-tenant, organization, workspace); apply everything below to that column.

## Row Level Security (default model)

Every table with a `tenant_id`:

```sql
CREATE TABLE IF NOT EXISTS public.projects (
  id         uuid        NOT NULL DEFAULT uuidv7(),
  tenant_id  uuid        NOT NULL,
  name       text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_projects PRIMARY KEY (id),
  CONSTRAINT fk_projects_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.tenants (id) ON DELETE RESTRICT,
  CONSTRAINT uq_projects_tenant_id_name UNIQUE (tenant_id, name)
);
CREATE INDEX IF NOT EXISTS idx_projects_tenant_id_created_at ON public.projects (tenant_id, created_at);

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE schemaname = 'public' AND tablename = 'projects' AND policyname = 'tenant_isolation') THEN
    CREATE POLICY tenant_isolation ON public.projects
      USING (tenant_id = public.current_tenant_id())
      WITH CHECK (tenant_id = public.current_tenant_id());
  END IF;
END $$;
```

Rules and the reasons behind them:

- **`ENABLE` and `FORCE`.** `ENABLE` alone exempts the table owner; `FORCE` applies the policy to the owner too, so a misconfigured consumer that connects as the owner is still isolated.
- **`USING` and `WITH CHECK`.** `USING` filters what can be read/updated/deleted; `WITH CHECK` stops writing rows into another tenant.
- **`current_tenant_id()`** (`templates/database/functions/current-tenant-id.sql`) reads `current_setting('app.tenant_id', true)` and turns an empty value into `NULL`. With no tenant set, policies match zero rows — a safe failure instead of a leak or an error.
- **The consumer sets the tenant per transaction**, with the transaction-local form:
  ```sql
  BEGIN;
  SELECT set_config('app.tenant_id', $1, true);   -- true = local to this transaction, like SET LOCAL
  -- queries…
  COMMIT;
  ```
  Never at session level (`SET app.tenant_id`, or `set_config(…, false)`): with a pooler in transaction mode (PgBouncer) the next transaction on that connection may belong to another tenant. Transaction-local settings are the only form that is correct with and without a pooler.
- **`tenant_id` first** in composite indexes and unique constraints of tenant tables, because every query is filtered by it.
- **Child tables also carry `tenant_id`** (denormalized from the parent) so each has its own policy and index; a composite FK `(tenant_id, parent_id) → parent (tenant_id, id)` guarantees a child can't point to another tenant's parent. That requires `UNIQUE (tenant_id, id)` on the parent.
- **Global tables** (the `tenants` table, catalogs) have no `tenant_id` and no tenant policy; grant them read-only to consumers if they must see them.
- **Bypass**: superusers and roles with `BYPASSRLS` skip policies. Only the owner/migrator role has `BYPASSRLS` (it must backfill across tenants); application roles never do. The bootstrap integrity checks verify both.
- Cross-tenant operations (admin dashboards, billing jobs) use a dedicated role and a `SECURITY DEFINER` function with a narrow purpose, never by disabling RLS.

Test isolation explicitly when adding a tenant table: as the API role, set tenant A, insert, switch to tenant B, and confirm the row is invisible and that inserting with tenant A's id fails.

## Roles (DCL)

Template: `templates/database/security/roles.sql`.

| Role | Kind | Member of | Purpose |
|---|---|---|---|
| `<p>_rw` | NOLOGIN group | — | Read/write privileges on application tables |
| `<p>_ro` | NOLOGIN group | — | Read-only privileges |
| `<p>_owner` | LOGIN | — | Owns every object; runs migrations; `BYPASSRLS`; never used by applications |
| `<p>_api` | LOGIN | `<p>_rw` | Backend / API |
| `<p>_worker` | LOGIN | `<p>_rw` | Background jobs |
| `<p>_readonly` | LOGIN | `<p>_ro` | Analytics, BI, support |
| `postgres` | superuser | — | Administration only |

Add or remove consumers as the project needs; each gets its own login so activity, connections and revocation are per consumer. Privileges are granted to the groups, never to logins.

## Grants

Template: `templates/database/security/grants.sql`. For each schema:

1. `REVOKE ALL ON SCHEMA … FROM PUBLIC`; `GRANT USAGE` to the groups.
2. Grants on existing objects (`ON ALL TABLES IN SCHEMA`), because bootstrap creates tables before grants run.
3. `ALTER DEFAULT PRIVILEGES FOR ROLE <owner> IN SCHEMA …` so tables and sequences created later by migrations inherit the same grants.
4. Functions: `ALTER DEFAULT PRIVILEGES FOR ROLE <owner> REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` (global, without `IN SCHEMA`), then `GRANT EXECUTE` function by function. Functions used inside policies (`current_tenant_id`) must be executable by every role that queries tenant tables.
5. Append-only tables: revoke `UPDATE, DELETE` from the groups.

At database level (in `roles.sql`, because it needs the database owner): `REVOKE ALL ON DATABASE … FROM PUBLIC`, `GRANT CONNECT` to the groups, `GRANT CONNECT, CREATE, TEMPORARY` to the owner.

Extensions live in the `extensions` schema (owned by the superuser) so schema-wide revokes on application schemas never touch extension functions.

## Secrets

- Passwords come from environment variables (`DB_OWNER_PASSWORD`, `DB_API_PASSWORD`…) read with `\getenv`. A missing variable aborts the bootstrap.
- `.env` is git-ignored; `.env.example` lists names with empty values.
- Never put credentials in seeds, migrations, flows, ADRs or `bootstrap.sql`. Password rotation is an operational task (`ALTER ROLE … PASSWORD` run by an operator), not a migration.
- Application password hashing happens in the application (argon2id/bcrypt). The database stores the hash only.
