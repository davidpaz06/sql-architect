# init

Create an empty database repo skeleton, without a blueprint.

1. Ask the scaffolding questions from `SKILL.md` workflow 2 (skip "which blueprint"). Ask for the project slug used to prefix roles (default: the project name in snake_case).
2. Read `references/repo-structure.md` and `references/docker.md`.
3. Show the tree and wait for confirmation.
4. Create:
   - `database/` from `templates/database/` (extensions, schemas, checks, security, functions `current-tenant-id`/`set-updated-at`/`prevent-mutation`, model `000-schema-migrations.sql`, `triggers/updated-at.sql`). Drop `current-tenant-id.sql` and its grant for single-tenant projects; drop `prevent-mutation.sql` if no append-only table is planned.
   - `database/migrations/.gitkeep`, `docs/flows/.gitkeep`, `docs/adr/.gitkeep`.
   - `database/seeds/dev.sql` only if the user wants the dev seed, plus `docker-compose.dev.yml`.
   - Root files from `templates/`: chosen build script, `docker-compose.yml`, `contributing.md` (replace `<build>` with the real command), `gitignore` → `.gitignore`, `gitattributes` → `.gitattributes`, `env.example` → `.env.example`, and an empty `playground.sql`.
   - `docker/db.Dockerfile` only if chosen extensions require it; then switch compose to `build:`.
   - `docs/integration-contract.md` (see `references/integration-contract.md`).
5. Replace the `app_` role prefix with the project slug everywhere (roles, grants, schemas, checks, migration template references, `.env.example`), and set `POSTGRES_DB`.
6. Uncomment the chosen extensions in `extensions.sql` and the matching `shared_preload_libraries` line in compose.
7. Run the build, then `check`. If Docker is available, `docker compose up -d` with a temporary `.env` and confirm the logs show no errors; run the bootstrap a second time to confirm idempotency.
8. Report the tree created and the next step (`/sql-architect generate` or modeling the first entities).
