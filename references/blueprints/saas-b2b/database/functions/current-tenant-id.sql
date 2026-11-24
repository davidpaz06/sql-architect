-- current-tenant-id.sql
-- Tenant of the current transaction, set by the consumer with set_config('app.tenant_id', <uuid>, true).
-- NULL when unset, so RLS policies return zero rows instead of failing.
CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT nullif(current_setting('app.tenant_id', true), '')::uuid
$$;
