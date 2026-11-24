# migrate

Create a migration for `<concept>` and keep the three parts consistent.

1. Read `references/migrations.md` and `references/idempotency-patterns.md`.
2. Read the affected sources of truth and any related flow/ADR. Clarify the change if `<concept>` is ambiguous.
3. Decide whether it's breaking for running consumers. If yes, propose the expand/contract sequence and create only the migrations for the current phase (usually *expand*, plus the backfill if small), explaining the rest.
4. Number: highest existing `MIG-NNN` + 1. Timestamp: current UTC time as `YYYYMMDDHHmm`. Name: `MIG-NNN-<concept-in-kebab-case>-<timestamp>.sql`.
5. Write it from `templates/migration.sql` (or `migration-no-transaction.sql` for concurrent index operations — one statement per file). Use the project's owner role in `SET LOCAL ROLE`.
6. Update the sources of truth so they describe the schema after the migration: models, functions, triggers, grants (new functions!), seeds, checks.
7. If it adds an ADR-worthy decision (denormalization, partitioning), create the ADR (`adr` command).
8. Rebuild and `check`. If a database is reachable, apply the migration twice (second run prints `skip`) and, when the repo has a base branch, run the drift test from `references/drift-check.md`.
9. Show the migration and the list of source files changed.
