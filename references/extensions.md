# Extensions

At scaffolding, propose only the extensions the project's intentions call for, ask the user to confirm, and ask the **target hosting** — managed providers allow a fixed list (check the provider's current docs before promising one). All extensions are installed in the `extensions` schema (`templates/database/extensions.sql`).

| Extension | Recommend when… | Don't recommend for… | Notes |
|---|---|---|---|
| `pg_stat_statements` | Almost always, as soon as the project has real traffic: it's the evidence base for indexes and tuning | — | Needs `shared_preload_libraries`. In the official image |
| `pgcrypto` | Column-level encryption or digests (`pgp_sym_encrypt`, `digest`, `hmac`) of sensitive fields | UUIDs (`gen_random_uuid()` and `uuidv7()` are native); password hashing (done in the application by default, so plaintext never reaches the database or its logs) | In the official image |
| `pg_trgm` | Fuzzy search, typo tolerance, autocomplete, frequent `LIKE '%x%'` / `ILIKE` (GIN or GiST trigram index) | Ranked full-text over documents (use `tsvector`) | In the official image |
| `citext` | Case-insensitive unique identifiers (email, usernames) without expression indexes | Free text | In the official image |
| `vector` (pgvector) | Embeddings, semantic search, RAG, recommendations (HNSW index) | Exact filtering — combine with normal WHERE clauses | Package `postgresql-18-pgvector` (custom image) |
| `postgis` | Distances, coverage radius, delivery zones, geofencing, any geospatial query | Storing a single lat/lng pair just to display it (two `numeric` columns or `point` suffice) | Package `postgresql-18-postgis-3` (custom image). Heavy |
| `ltree` | Hierarchies queried by path: categories, org charts, folder trees | Shallow or rarely-queried trees — recursive CTEs or a closure table are simpler | In the official image |
| `btree_gin` | One GIN index combining scalar columns with arrays/JSONB/tsvector (e.g. `(tenant_id, tags)`) | — | In the official image |
| `btree_gist` | Exclusion constraints mixing equality and ranges: no overlapping bookings per resource | — | In the official image |
| `pg_cron` | Scheduled jobs inside the database: creating future partitions, retention purges, refreshing materialized views | Application workflows, anything calling external services | Package `postgresql-18-cron`; `shared_preload_libraries` + `cron.database_name`. Managed providers may offer it natively |
| `pg_partman` | Many time-partitioned tables needing automatic creation and retention | One or two partitioned tables (a small function + pg_cron is enough) | Package `postgresql-18-partman` |
| `unaccent` | Accent-insensitive search (Spanish/Portuguese text) | — | In the official image; wrap in an immutable function to index it |

Example exclusion constraint with `btree_gist`:

```sql
CONSTRAINT ex_bookings_resource_id_period
  EXCLUDE USING gist (resource_id WITH =, period WITH &&)
```

Every extension added after the first deploy is a migration (`CREATE EXTENSION IF NOT EXISTS … WITH SCHEMA extensions`) plus the update to `extensions.sql`, and, if it needs a package, the Dockerfile.
