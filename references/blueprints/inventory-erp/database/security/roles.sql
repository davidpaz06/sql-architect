-- roles.sql
-- Cluster roles: NOLOGIN groups plus one LOGIN role per consumer. Passwords come from the environment.
-- Runs as superuser, before schemas. Rename the "app_" prefix to the project slug when scaffolding.

\getenv owner_password DB_OWNER_PASSWORD
\getenv api_password DB_API_PASSWORD
\getenv worker_password DB_WORKER_PASSWORD
\getenv readonly_password DB_READONLY_PASSWORD

-- Fail fast (and roll back) if a password is missing
\if :{?owner_password}
\else
  DO $$ BEGIN RAISE EXCEPTION 'missing environment variable DB_OWNER_PASSWORD'; END $$;
\endif
\if :{?api_password}
\else
  DO $$ BEGIN RAISE EXCEPTION 'missing environment variable DB_API_PASSWORD'; END $$;
\endif
\if :{?worker_password}
\else
  DO $$ BEGIN RAISE EXCEPTION 'missing environment variable DB_WORKER_PASSWORD'; END $$;
\endif
\if :{?readonly_password}
\else
  DO $$ BEGIN RAISE EXCEPTION 'missing environment variable DB_READONLY_PASSWORD'; END $$;
\endif

-- Group roles (privileges are granted to these, never to login roles)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_rw') THEN CREATE ROLE app_rw NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_ro') THEN CREATE ROLE app_ro NOLOGIN; END IF;
END $$;

-- Owner / migrator: owns every object. BYPASSRLS so migrations can backfill across tenants.
-- Never used by the application at runtime.
SELECT format('CREATE ROLE app_owner LOGIN BYPASSRLS PASSWORD %L', :'owner_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_owner') \gexec

-- Consumers
SELECT format('CREATE ROLE app_api LOGIN PASSWORD %L IN ROLE app_rw', :'api_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_api') \gexec

SELECT format('CREATE ROLE app_worker LOGIN PASSWORD %L IN ROLE app_rw', :'worker_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_worker') \gexec

SELECT format('CREATE ROLE app_readonly LOGIN PASSWORD %L IN ROLE app_ro', :'readonly_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_readonly') \gexec

-- Database-level privileges (need the database owner or a superuser, so they live here)
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database()) \gexec
SELECT format('GRANT CONNECT, CREATE, TEMPORARY ON DATABASE %I TO app_owner', current_database()) \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO app_rw, app_ro', current_database()) \gexec
