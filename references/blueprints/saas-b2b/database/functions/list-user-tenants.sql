-- list-user-tenants.sql
-- Tenants a signed-in user belongs to, so the consumer can pick the tenant context (bypasses RLS).
CREATE OR REPLACE FUNCTION public.list_user_tenants(p_user_id uuid)
RETURNS TABLE (tenant_id uuid, name text, slug text, role text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT t.id, t.name, t.slug, m.role
  FROM public.memberships m
  JOIN public.tenants t ON t.id = m.tenant_id
  WHERE m.user_id = p_user_id AND t.status = 'active'
  ORDER BY t.name
$$;
