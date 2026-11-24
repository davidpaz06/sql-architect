-- register-tenant.sql
-- Sign-up: creates tenant, owner user, owner membership, trial subscription and audit row atomically.
-- Flow: docs/flows/new-tenant-registration.md
CREATE OR REPLACE FUNCTION public.register_tenant(
  p_tenant_name    text,
  p_slug           text,
  p_email          text,
  p_full_name      text,
  p_password_hash  text,
  p_plan_code      text DEFAULT 'free',
  p_trial_days     integer DEFAULT 14
)
RETURNS TABLE (tenant_id uuid, user_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, extensions
AS $$
DECLARE
  v_tenant_id uuid;
  v_user_id   uuid;
  v_plan_id   integer;
BEGIN
  IF EXISTS (SELECT 1 FROM public.users u WHERE u.email = p_email::citext) THEN
    RAISE EXCEPTION 'email % is already registered', p_email
      USING ERRCODE = 'AP101', HINT = 'Sign in and create the organization from the account instead';
  END IF;

  IF EXISTS (SELECT 1 FROM public.tenants t WHERE t.slug = p_slug) THEN
    RAISE EXCEPTION 'slug % is taken', p_slug USING ERRCODE = 'AP102';
  END IF;

  SELECT p.id INTO v_plan_id FROM public.plans p WHERE p.code = p_plan_code AND p.is_active;
  IF v_plan_id IS NULL THEN
    RAISE EXCEPTION 'plan % does not exist or is inactive', p_plan_code USING ERRCODE = 'AP104';
  END IF;

  INSERT INTO public.tenants (name, slug) VALUES (p_tenant_name, p_slug)
  RETURNING id INTO v_tenant_id;

  INSERT INTO public.users (email, full_name, password_hash) VALUES (p_email, p_full_name, p_password_hash)
  RETURNING id INTO v_user_id;

  INSERT INTO public.memberships (tenant_id, user_id, role) VALUES (v_tenant_id, v_user_id, 'owner');

  INSERT INTO public.subscriptions (tenant_id, plan_id, status, current_period_start, current_period_end)
  VALUES (v_tenant_id, v_plan_id, 'trialing', now(), now() + make_interval(days => p_trial_days));

  INSERT INTO public.audit_logs (tenant_id, actor_user_id, action, entity, entity_id)
  VALUES (v_tenant_id, v_user_id, 'tenant.registered', 'tenants', v_tenant_id);

  RETURN QUERY SELECT v_tenant_id, v_user_id;
END
$$;
