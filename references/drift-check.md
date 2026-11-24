# Drift Check

Three automated checks keep the sources of truth, `bootstrap.sql` and the migrations consistent. Run the first one locally before every commit; run all three in CI on every pull request.

## 1. Build check (fast, no database)

```bash
<build> check
```

Fails when `bootstrap.sql` is stale, migrations are badly named or numbered, a file is not kebab-case, or a SQL file lacks its header. Optional pre-commit hook (`.git/hooks/pre-commit`):

```bash
#!/bin/sh
node build.mjs check || { echo "run: node build.mjs build"; exit 1; }
```

## 2. Idempotency (bootstrap twice)

On a throwaway `postgres:18`, run `bootstrap.sql` twice. The second run must succeed and change nothing. Also run each migration twice: the second run must print `skip … (already applied)`.

## 3. Drift (bootstrap vs migrations)

Proves that a database created *before* this change, plus the new migrations, ends up identical to a database created *from* the new sources.

1. Database A: run `bootstrap.sql` from the **base** branch (e.g. `git show origin/main:bootstrap.sql` together with that commit's `database/`), then apply the migrations added in this branch.
2. Database B: run `bootstrap.sql` from the current branch.
3. Compare `pg_dump --schema-only --no-owner --no-privileges` of A and B. Any difference is drift: a migration that the sources don't reflect, or vice versa.

Grants and owners are compared separately with `--schema-only` including privileges if the project relies on them.

### GitHub Actions example

```yaml
name: database
on: [pull_request]
jobs:
  db:
    runs-on: ubuntu-latest
    services:
      pg:
        image: postgres:18
        env: { POSTGRES_PASSWORD: postgres }
        ports: ["5432:5432"]
        options: --health-cmd pg_isready --health-interval 5s --health-retries 10
    env:
      PGHOST: localhost
      PGUSER: postgres
      PGPASSWORD: postgres
      DB_OWNER_PASSWORD: ci
      DB_API_PASSWORD: ci
      DB_WORKER_PASSWORD: ci
      DB_READONLY_PASSWORD: ci
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Build check
        run: node build.mjs check
      - name: Idempotency
        run: |
          createdb b
          psql -d b -X -f bootstrap.sql
          psql -d b -X -f bootstrap.sql
      - name: Drift
        run: |
          git worktree add /tmp/base origin/${{ github.base_ref }}
          createdb a
          psql -d a -X -f /tmp/base/bootstrap.sql
          for f in database/migrations/MIG-*.sql; do psql -d a -X -v ON_ERROR_STOP=1 -f "$f"; done
          pg_dump -d a --schema-only --no-owner --no-privileges > a.sql
          pg_dump -d b --schema-only --no-owner --no-privileges > b.sql
          diff -u a.sql b.sql
```

Roles are cluster-wide: running two bootstraps on the same server is fine because role creation is idempotent.

Extensions that need packages outside `postgres:18` require building `docker/db.Dockerfile` in CI instead of using the service image directly.
