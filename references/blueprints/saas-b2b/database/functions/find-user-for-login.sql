-- find-user-for-login.sql
-- Returns the credentials needed to verify a sign-in, before any tenant is selected (bypasses RLS on users).
CREATE OR REPLACE FUNCTION public.find_user_for_login(p_email text)
RETURNS TABLE (user_id uuid, password_hash text, is_active boolean)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, extensions
AS $$
  SELECT u.id, u.password_hash, u.is_active
  FROM public.users u
  WHERE u.email = p_email::citext
$$;
