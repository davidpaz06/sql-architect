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
  IF (SELECT count(*) FROM public.plans WHERE code IN ('free', 'pro', 'business')) <> 3 THEN
    RAISE EXCEPTION 'integrity: plans seed incomplete';
  END IF;

  -- RLS on global tables that have no tenant_id column (not covered by the generated check)
  IF EXISTS (SELECT 1 FROM pg_class
             WHERE oid IN ('public.tenants'::regclass, 'public.users'::regclass)
               AND NOT (relrowsecurity AND relforcerowsecurity)) THEN
    RAISE EXCEPTION 'integrity: tenants and users must have RLS enabled and forced';
  END IF;
END $$;
