# Bootstrap and Build

## What bootstrap.sql is

A **generated** psql script that creates the whole database from the sources of truth, in one transaction. It contains no SQL of its own except the header, the migration baseline and the generic RLS check; everything else is `\ir` includes of files under `database/`.

```sql
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL check_function_bodies = off;   -- functions may reference tables created later
\ir database/extensions.sql
\ir database/security/roles.sql
\ir database/schemas.sql                 -- ends with SET LOCAL ROLE <owner>
\ir database/functions/…
\ir database/models/…
\ir database/triggers/…
\ir database/security/grants.sql
\ir database/seeds/…
RESET ROLE;
INSERT INTO public.schema_migrations (id, applied_by) VALUES (…) ON CONFLICT DO NOTHING;
DO $$ … RLS integrity check … $$;
\ir database/checks.sql
COMMIT;
```

### Why each piece is there

- **`\set ON_ERROR_STOP on` inside the file**: the script aborts on the first error no matter how it is invoked. Combined with `BEGIN … COMMIT`, any error leaves the database untouched (PostgreSQL DDL is transactional).
- **`\ir`, not `\i`**: `\ir` resolves paths relative to the script itself, so the bootstrap works from the repo root, from CI, and inside the Docker entrypoint, where it is mounted at `/docker-entrypoint-initdb.d/01-bootstrap.sql` next to `database/`.
- **`check_function_bodies = off`**: lets SQL-language functions be created before the tables they reference.
- **Owner switch**: everything after `schemas.sql` runs as the owner role, so objects are owned by it and default privileges apply to future objects created by migrations.
- **Migration baseline**: the sources already include every migration's effect, so all existing migration ids are recorded as applied (`applied_by = 'bootstrap'`). Running the migrations afterwards is a no-op.
- **Integrity checks**: a failed check raises, which rolls back the entire bootstrap. The generated check verifies that every table with a `tenant_id` column has RLS enabled, forced and at least one policy. `checks.sql` adds project checks: roles exist, application roles are not `BYPASSRLS`, reference seeds are complete.

### Idempotency and its limit

Every source file must be idempotent (see `idempotency-patterns.md`), so running the bootstrap twice changes nothing and loses no data. That makes it safe as a quick "bring my local DB up to date with new tables" — **but it cannot alter existing tables**: `CREATE TABLE IF NOT EXISTS` skips a table whose columns changed. That is why bootstrap is only for **new environments** (local, CI, the first deploy of production) and existing databases only receive migrations.

### Secrets

`roles.sql` reads passwords with `\getenv` from the environment and fails (rolling back) if one is missing. psql does not interpolate variables inside `$$` bodies, so the values are applied with `SELECT format(…, :'var') … \gexec`. Never write a password into any file.

## Running it

| Target | Command |
|---|---|
| Local Docker | `docker compose up -d` (runs once, on an empty volume) |
| Fresh managed database | `psql "$ADMIN_DATABASE_URL" -f bootstrap.sql`, from the repo root, with the `DB_*_PASSWORD` variables exported |
| CI | same as managed, against a throwaway `postgres:18` service |

Managed providers (Supabase, RDS, Cloud SQL) don't give a real superuser. Before the first bootstrap there, check which statements need adjusting: `CREATE EXTENSION` for non-allowed extensions, `BYPASSRLS` on the owner role, `ALTER DATABASE … SET`. Adapt `roles.sql`/`extensions.sql` and record the difference in an ADR.

## The build script

Copy **one** of `templates/build.mjs`, `templates/build.py`, `templates/build.ps1` to the repo root, according to the user's choice. The three are interchangeable: same commands, byte-identical output, no dependencies.

| Command | Effect |
|---|---|
| `build` | Regenerates `bootstrap.sql` deterministically from `database/` |
| `check` | Fails (exit 1) when `bootstrap.sql` is stale, migration names or numbering are wrong, a file or folder is not kebab-case, a SQL file lacks its two-line header, or the `schema_migrations` model is missing |
| `migrate` | Applies every migration in order with psql against `DATABASE_URL`. Each file's guard skips it if already applied, so this applies only the pending ones |
| `migrate --docker` (`-Docker` in PowerShell) | Same, through `docker compose exec` into the `db` service |

Invocation: `node build.mjs <cmd>`, `python build.py <cmd>`, `./build.ps1 <cmd>`.

### Ordering rules the build applies

- Within each section, files are sorted by **file name**, then by relative path, with ordinal comparison. Numeric prefixes therefore order dependencies across schema folders.
- Migrations are sorted by their number.
- `seeds/dev.sql` and `security/roles.sql` are excluded from their generic sections.

### When to run it

After **every** change under `database/`. The commit that changes the schema includes the regenerated `bootstrap.sql`. Wire `check` into CI and, ideally, a pre-commit hook — see `drift-check.md`.

### Line endings

The build normalizes CRLF to LF when comparing, and the template `.gitattributes` forces LF so `bootstrap.sql` is identical across Windows, macOS and Linux.
