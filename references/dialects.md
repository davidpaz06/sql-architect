# Dialects

PostgreSQL 18 is the reference. The **principles** of this skill hold on any SQL engine: sources of truth + generated bootstrap, forward-only idempotent migrations with a registry table, expand/contract, ADRs, 3NF by default, naming conventions, least-privilege roles, no speculative indexes. What changes is the mechanics. Read this before writing SQL for another engine, and state the differences to the user up front.

## PostgreSQL-specific features used by the skill

| Feature | MySQL 8 / MariaDB | SQL Server | SQLite |
|---|---|---|---|
| Transactional DDL (atomic bootstrap and migrations) | **No** — DDL commits implicitly; a failed bootstrap leaves partial state. Use a throwaway database and drop it on failure | Yes (most DDL) | Yes |
| psql `\ir`, `\getenv`, `\gexec`, `\if` | No: the build must concatenate files into one script; secrets via the client tool or templating | `sqlcmd` has `:r` include and `$(var)` variables | `.read` include only |
| Row Level Security | **No** — isolate tenants with views + definer routines, or in the application | Yes (security policies + predicate functions) | No |
| `uuidv7()` | No native v7: generate in the application and store as `BINARY(16)`; MySQL `UUID()` is v1 | `NEWSEQUENTIALID()` (ordered, not v7) or app-generated | App-generated, stored as BLOB/TEXT |
| `GENERATED ALWAYS AS IDENTITY` | `AUTO_INCREMENT` | `IDENTITY(1,1)` | `INTEGER PRIMARY KEY` |
| `timestamptz` | `TIMESTAMP` (UTC conversion, 2038 limit) or `DATETIME(6)` stored in UTC | `datetimeoffset` | TEXT/INTEGER in UTC |
| `IF NOT EXISTS` coverage | Tables, indexes (MariaDB), not constraints | `IF OBJECT_ID(…) IS NULL` / `CREATE OR ALTER` | Tables, indexes, triggers |
| `ON CONFLICT` | `INSERT … ON DUPLICATE KEY UPDATE` / `INSERT IGNORE` | `MERGE` or `IF NOT EXISTS` | `ON CONFLICT` (same syntax) |
| `CREATE OR REPLACE TRIGGER` | Drop + create | `CREATE OR ALTER TRIGGER` | Drop + create |
| Partial / expression indexes | Functional indexes (8.0.13+); no partial | Filtered indexes | Both |
| `jsonb` + GIN | `JSON` + generated-column indexes / multi-valued indexes | `nvarchar` JSON + computed-column indexes | JSON functions, no GIN |
| Exclusion constraints | No | No (use triggers or app logic) | No |
| Declarative partitioning | Yes (PK must include the key) | Partition functions/schemes | No |
| Schemas as namespaces | A "schema" is a database | Yes | Attached databases only |
| Extensions (`pg_trgm`, `vector`, PostGIS…) | FULLTEXT, spatial types built in; vector in recent versions | Full-text, spatial built in | FTS5, extensions loaded per connection |
| `CREATE INDEX CONCURRENTLY` | `ALGORITHM=INPLACE, LOCK=NONE` | `ONLINE = ON` (Enterprise) | N/A |

## Practical guidance

- Keep the repo layout, naming, ADRs and migration discipline identical; adapt the build to emit one concatenated script when the client has no include command.
- Without transactional DDL (MySQL/MariaDB), make migrations small (one DDL statement each) so a failure is easy to resume, and keep the registry insert as the last statement.
- Without RLS, write the tenant-isolation strategy as an ADR and include it in the integration contract, since enforcement moves to the consumer.
- SQLite is for embedded/local use: skip roles, grants and RLS entirely.
