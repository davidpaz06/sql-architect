-- checks.sql
-- Project integrity checks, run at the end of bootstrap. Any exception rolls back everything.
DO $$
BEGIN
  -- Roles exist and application roles cannot bypass RLS
  IF EXISTS (
    SELECT 1 FROM unnest(ARRAY['app_owner', 'app_api', 'app_worker', 'app_readonly', 'app_rw', 'app_ro']) AS r(name)
    WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r.name)
  ) THEN
    RAISE EXCEPTION 'integrity: expected roles are missing';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_roles
    WHERE rolname IN ('app_api', 'app_worker', 'app_readonly') AND (rolsuper OR rolbypassrls)
  ) THEN
    RAISE EXCEPTION 'integrity: application roles must not be superuser or BYPASSRLS';
  END IF;

  -- Reference seeds: one check per seeded table, e.g.
  -- IF (SELECT count(*) FROM public.currencies) < 3 THEN
  --   RAISE EXCEPTION 'integrity: currencies seed incomplete';
  -- END IF;
END $$;
