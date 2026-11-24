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

  -- Reference seeds
  IF (SELECT count(*) FROM public.currencies WHERE code IN ('EUR', 'USD')) <> 2 THEN
    RAISE EXCEPTION 'integrity: currencies seed incomplete';
  END IF;
  IF (SELECT count(*) FROM public.account_types) <> 5 THEN
    RAISE EXCEPTION 'integrity: account_types seed must have exactly the 5 fundamental types';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.accounts) THEN
    RAISE EXCEPTION 'integrity: chart of accounts seed is empty';
  END IF;
END $$;
