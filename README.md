# sql-architect

Skill for designing SQL databases with PostgreSQL 18 as the reference engine. It models databases that work for an MVP and can scale later, and keeps them in a git repository that every developer can read in the editor and bring up locally with one command.

## What it covers

- A git-versioned database repo: sources of truth in `database/`, a generated `bootstrap.sql` that runs in one transaction and can be run twice safely, forward-only migrations, and docs (`flows/`, `adr/`).
- A build script in three interchangeable versions (Node, Python, PowerShell) that regenerates `bootstrap.sql`, checks the repo's conventions and applies pending migrations.
- Docker on a pinned `postgres:18` image, with a recipe for adding pgvector, PostGIS, pg_cron and pg_partman.
- Migrations with a `schema_migrations` registry, a guard at the top of each file, lock-safe DDL and the expand/contract pattern.
- Multi-tenancy with Row Level Security, least-privilege roles and grants, and passwords read from the environment.
- Conventions: naming, uuidv7 keys and identity catalogs, types, audit columns, soft delete.
- Guidance on functions, triggers and a SQLSTATE error contract, plus seeds, indexing, partitioning, the scaling ladder and an extensions catalog.
- Normalization to 3NF, with every denormalization recorded as an ADR.
- An integration contract that lets any backend consume the database without coupling to it.
- Blueprints for common MVPs, and quick commands.

## Quick commands

```text
/sql-architect init                     empty repo skeleton
/sql-architect generate saas-b2b ...    repo from a blueprint, adapted to your notes
/sql-architect migrate add-phone-to-users
/sql-architect devseed medium           deterministic mock data
/sql-architect audit                    normal forms, conventions, ADRs, queries, scaling level
/sql-architect check                    build check + idempotency (+ --drift)
/sql-architect adr jsonb-product-attributes
/sql-architect explain "SELECT ..."
/sql-architect erd
```

## Core conventions

- Files and folders use kebab-case. SQL identifiers use snake_case. Table names are plural, and columns are short with no table prefix.
- Entity tables use `uuid DEFAULT uuidv7()` keys. Small catalogs use `GENERATED ALWAYS AS IDENTITY`.
- Every schema change ships in one commit with three parts: updated sources, a new migration and a rebuilt `bootstrap.sql`.
- Bootstrap runs only on new environments. Existing databases receive migrations.
- Multi-tenant tables use `tenant_id` with RLS enabled and forced. The tenant is set per transaction with `set_config('app.tenant_id', …, true)`.
- Application roles never own objects and never bypass RLS.
- The directory tree is confirmed with the user before scaffolding.
- Application code and frontend are out of scope.

All conventions are defaults and can be overridden for a project or conversation.

## Installation

### Personal installation

```bash
git clone https://github.com/davidpaz06/sql-architect.git ~/.claude/skills/sql-architect
```

### Project-only installation

```bash
git submodule add https://github.com/davidpaz06/sql-architect.git .claude/skills/sql-architect
```

### From a downloaded `.zip` or `.skill` file

```bash
# A .skill file is a ZIP archive with a different extension.
mv sql-architect.skill sql-architect.zip
unzip sql-architect.zip -d ~/.claude/skills/sql-architect
```

PowerShell:

```powershell
Rename-Item -Path "sql-architect.skill" -NewName "sql-architect.zip"
Expand-Archive -Path "sql-architect.zip" -DestinationPath "$HOME\.claude\skills\sql-architect" -Force
```

## Updating

```bash
cd ~/.claude/skills/sql-architect
git pull
```

## Repository structure

```text
sql-architect/
|-- SKILL.md
|-- README.md
|-- CHANGELOG.md
|-- references/
|   |-- repo-structure.md, bootstrap-and-build.md, idempotency-patterns.md
|   |-- migrations.md, drift-check.md, docker.md
|   |-- conventions.md, keys-and-types.md, security.md
|   |-- functions-and-triggers.md, seeds.md, indexing.md, partitioning.md
|   |-- scaling-ladder.md, extensions.md, normalization-and-adr.md
|   |-- integration-contract.md, dialects.md, anti-patterns.md
|   |-- commands/      one procedure per quick command
|   `-- blueprints/    saas-b2b, e-commerce, inventory-erp, finance-accounting (+ index of pending ones)
|-- templates/         files copied into generated repos (build scripts, compose, SQL, migration/ADR/flow templates)
`-- scripts/
    `-- verify-blueprints.sh
```

Start with [`SKILL.md`](SKILL.md) for the workflows and commands.

## Maintaining the blueprints

After editing a blueprint or a template, run:

```bash
bash scripts/verify-blueprints.sh            # all blueprints
bash scripts/verify-blueprints.sh saas-b2b   # one
```

For each blueprint, it checks that the Node and Python builds produce the same output and that the build check passes. It then runs the bootstrap twice on `postgres:18`, runs the dev seed twice, and reports shared files that have drifted from `templates/database`.

## Requirements

- PostgreSQL 18 (reference engine; see `references/dialects.md` for others)
- Docker, for local databases and verification
- psql client
- Node.js 18+, Python 3.9+ or PowerShell 5.1+, for whichever build script the project uses
