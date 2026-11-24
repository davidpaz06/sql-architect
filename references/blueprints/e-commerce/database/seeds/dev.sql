-- dev.sql
-- Deterministic mock data for local development. Not part of bootstrap. Idempotent.
-- Run: psql "$DATABASE_URL" -f database/seeds/dev.sql   (as a superuser, so RLS does not filter inserts)

\set ON_ERROR_STOP on
\getenv app_env APP_ENV
\if :{?app_env}
\else
  \set app_env ''
\endif
SELECT set_config('seed.app_env', :'app_env', false);

BEGIN;

DO $$
BEGIN
  IF current_setting('seed.app_env') NOT IN ('development', 'local', 'test') THEN
    RAISE EXCEPTION 'dev seed refuses to run: APP_ENV is "%" (allowed: development, local, test)',
      current_setting('seed.app_env');
  END IF;
END $$;

-- Deterministic ids: md5('<entity>-<n>')::uuid gives the same id on every run, so ON CONFLICT keeps it idempotent.
-- INSERT INTO public.tenants (id, name)
-- SELECT md5('tenant-' || n)::uuid, 'Tenant ' || n
-- FROM generate_series(1, 3) AS n
-- ON CONFLICT (id) DO NOTHING;

COMMIT;
