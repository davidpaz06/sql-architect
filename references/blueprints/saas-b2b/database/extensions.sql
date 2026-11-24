-- extensions.sql
-- Extensions required by the project, in their own schema. Runs first, as superuser. Keep only what is used.

-- A dedicated schema keeps extension objects (owned by the superuser) out of the application schemas,
-- so grants and revokes on public never touch them.
CREATE SCHEMA IF NOT EXISTS extensions;
GRANT USAGE ON SCHEMA extensions TO PUBLIC;

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;  -- also needs shared_preload_libraries
CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA extensions;              -- case-insensitive emails

-- Make extension types and functions resolvable without qualification, now and in future sessions.
SELECT format('ALTER DATABASE %I SET search_path = public, extensions', current_database()) \gexec
SET LOCAL search_path = public, extensions;
