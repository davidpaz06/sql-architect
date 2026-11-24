-- accept-invitation.sql
-- Accepts a pending invitation by token hash: creates the user if needed and the membership.
-- Flow: docs/flows/invitation-acceptance.md
CREATE OR REPLACE FUNCTION public.accept_invitation(
  p_token_hash     text,
  p_full_name      text,
  p_password_hash  text
)
RETURNS TABLE (tenant_id uuid, user_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, extensions
AS $$
DECLARE
  v_inv     public.invitations%ROWTYPE;
  v_user_id uuid;
BEGIN
  SELECT * INTO v_inv FROM public.invitations i
  WHERE i.token_hash = p_token_hash
  FOR UPDATE;

  IF NOT FOUND OR v_inv.accepted_at IS NOT NULL OR v_inv.expires_at <= now() THEN
    RAISE EXCEPTION 'invitation is invalid, already used or expired' USING ERRCODE = 'AP103';
  END IF;

  SELECT u.id INTO v_user_id FROM public.users u WHERE u.email = v_inv.email;
  IF v_user_id IS NULL THEN
    INSERT INTO public.users (email, full_name, password_hash)
    VALUES (v_inv.email, p_full_name, p_password_hash)
    RETURNING id INTO v_user_id;
  END IF;

  INSERT INTO public.memberships (tenant_id, user_id, role)
  VALUES (v_inv.tenant_id, v_user_id, v_inv.role)
  ON CONFLICT ON CONSTRAINT uq_memberships_tenant_id_user_id DO NOTHING;

  UPDATE public.invitations SET accepted_at = now() WHERE id = v_inv.id;

  INSERT INTO public.audit_logs (tenant_id, actor_user_id, action, entity, entity_id)
  VALUES (v_inv.tenant_id, v_user_id, 'member.joined', 'invitations', v_inv.id);

  RETURN QUERY SELECT v_inv.tenant_id, v_user_id;
END
$$;
