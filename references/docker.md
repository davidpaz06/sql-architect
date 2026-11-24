# Docker

## docker-compose.yml

Copy `templates/docker-compose.yml`. Key points:

- **Pinned image `postgres:18`.** Never `latest`: a major version change breaks the data directory.
- **Volume at `/var/lib/postgresql`.** PostgreSQL 18 images set `PGDATA=/var/lib/postgresql/18/docker`; mounting the parent keeps future major upgrades (`pg_upgrade --link`) possible.
- **Bootstrap mount**: `./bootstrap.sql → /docker-entrypoint-initdb.d/01-bootstrap.sql` and `./database → /docker-entrypoint-initdb.d/database`, both read-only. The entrypoint runs top-level `*.sql` files with psql (so `\ir` resolves next to the file) and ignores subfolders.
- **Runs once.** The entrypoint only runs init scripts when the data directory is empty, which matches "bootstrap only for new environments". Reset with `docker compose down -v`.
- **`env_file: .env`** passes `POSTGRES_*`, the `DB_*_PASSWORD` variables and `APP_ENV` to the container, where psql reads them with `\getenv`.
- **Healthcheck** with `pg_isready` so dependent services wait for a ready database.

Apply migrations to the running container: `<build> migrate --docker`.

If the init fails, the container exits and the volume is left half-initialized: read `docker compose logs db`, fix, then `docker compose down -v` before retrying.

## Dev seed

`templates/docker-compose.dev.yml` mounts `database/seeds/dev.sql` as `02-dev-seed.sql`, so it runs after the bootstrap on a fresh volume:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

On an existing volume, run it directly: `docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < database/seeds/dev.sql`.

## Extensions outside the official image

The official `postgres:18` image ships the contrib extensions (`pg_trgm`, `pgcrypto`, `citext`, `ltree`, `btree_gin`, `btree_gist`, `pg_stat_statements`…). It does **not** include `vector` (pgvector), `postgis`, `pg_cron` or `pg_partman`. When the project needs any of them, copy `templates/docker/db.Dockerfile` to `docker/db.Dockerfile`, keep only the needed packages, and switch the service from `image:` to `build:`.

PGDG package names for PostgreSQL 18 (verified against the PGDG repository the image configures):

| Extension | Package |
|---|---|
| `vector` | `postgresql-18-pgvector` |
| `postgis` | `postgresql-18-postgis-3` |
| `pg_cron` | `postgresql-18-cron` |
| `pg_partman` | `postgresql-18-partman` |

Re-verify when a new major is adopted: `docker run --rm postgres:<v> sh -c 'apt-get update -qq && apt-cache policy postgresql-<v>-pgvector'`.

## Preloaded libraries

`pg_stat_statements` and `pg_cron` must be in `shared_preload_libraries`; `pg_cron` also needs `cron.database_name`. Set them through `command:` in compose (the commented line in the template). Without the preload, `CREATE EXTENSION` still succeeds but the extension doesn't collect data or run jobs.

## Managed hosting

Containers are for local development and CI. In production on a managed service, the provider's console controls the version, extensions and preload libraries; the bootstrap is run once with psql (see `bootstrap-and-build.md`).
