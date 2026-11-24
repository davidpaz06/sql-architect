# Contributing to the database

## Bring it up locally

1. `cp .env.example .env` and fill in the passwords.
2. `docker compose up -d` — creates the database from `bootstrap.sql` on first start.
3. Optional mock data: `docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d` on a fresh volume,
   or run `database/seeds/dev.sql` with psql.
4. Start over: `docker compose down -v && docker compose up -d`.

## Where things live

- `database/` holds the **sources of truth**: they always describe the current schema.
  `extensions.sql`, `schemas.sql`, `checks.sql`, `security/` (roles, grants), `functions/`, `models/` (one table per file),
  `triggers/`, `seeds/` (reference data; `dev.sql` is mock data) and `migrations/`.
- `bootstrap.sql` is **generated**. Never edit it by hand.
- `docs/flows/` explains business flows that write to several tables. `docs/adr/` records design decisions.
- `playground.sql` is your personal scratch file and is git-ignored.

## Changing the schema

Every schema change is **one commit with three parts**:

1. Update the sources of truth so they describe the schema after the change.
2. Add a migration `database/migrations/MIG-NNN-<concept>-<YYYYMMDDHHmm>.sql` (copy the template;
   next number, UTC timestamp). Breaking changes use expand/contract across several migrations.
3. Rebuild: `<build> build`, then `<build> check` must pass.

Rules:
- Migrations are forward-only. To undo, write a new migration. Never edit a merged migration.
- If two branches take the same migration number, the second to merge renumbers before merging (`check` catches it).
- Denormalizations and deviations from the conventions need an ADR.

Apply pending migrations to a running database:
`<build> migrate --docker` (local container) or `<build> migrate` with `DATABASE_URL` set.

## Conventions

- Files and folders: kebab-case. SQL identifiers: snake_case. Tables in plural.
- Every SQL file starts with `-- <file name>` and a one-line `-- <purpose>`.
- Keys: `uuid DEFAULT uuidv7()`; small catalogs use identity integers.
- Every mutable table has `created_at` and `updated_at`.
