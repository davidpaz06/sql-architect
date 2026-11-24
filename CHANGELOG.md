# Changelog

All notable changes to the `sql-architect` skill are documented here.

This file follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-25

Initial versioned release.

### Added

- `SKILL.md` with the database-architect persona, non-negotiable defaults, scope, and workflows for advisory, scaffolding, modeling, migration, optimization and review tasks.
- Quick commands `/sql-architect <command>`: `init`, `generate`, `migrate`, `devseed`, `audit`, `check`, `adr`, `explain`, `erd`, each with its procedure in `references/commands/`.
- Git-versioned database repo layout: sources of truth in `database/`, generated atomic and idempotent `bootstrap.sql`, forward-only migrations with `schema_migrations` registry and per-file guards, `docs/flows` and `docs/adr`.
- Build script in three interchangeable versions (`build.mjs`, `build.py`, `build.ps1`) with `build`, `check` and `migrate` commands and byte-identical output.
- Docker setup on `postgres:18`, custom image recipe for pgvector/PostGIS/pg_cron/pg_partman, dev-seed compose override.
- References: conventions, keys and types (uuidv7, identity catalogs), RLS multi-tenancy and DCL, functions/triggers and SQLSTATE error contract, seeds, indexing, partitioning, scaling ladder, extensions catalog, normalization and ADR format, integration contract, dialect differences, drift checks, anti-patterns.
- Blueprints: multi-tenant SaaS B2B, e-commerce, inventory/ERP, finance and accounting — verified on PostgreSQL 18.7. Ten more listed as pending.
- `scripts/verify-blueprints.sh` to re-verify blueprints after edits.

[1.0.0]: https://github.com/davidpaz06/sql-architect/releases/tag/v1.0.0
