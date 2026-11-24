-- grants.sql
-- Least-privilege grants per schema, for existing objects and for objects created later by migrations.
-- Runs as app_owner. Repeat the block for every schema the project adds.

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO app_rw, app_ro;

-- Existing objects
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_rw;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_ro;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_rw;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- Objects created later by app_owner (migrations)
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_rw;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA public
  GRANT SELECT ON TABLES TO app_ro;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO app_rw;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- Functions are granted explicitly, one by one
GRANT EXECUTE ON FUNCTION public.current_tenant_id() TO app_rw, app_ro;
GRANT EXECUTE ON FUNCTION public.register_tenant(text, text, text, text, text, text, integer) TO app_rw;
GRANT EXECUTE ON FUNCTION public.accept_invitation(text, text, text) TO app_rw;
GRANT EXECUTE ON FUNCTION public.find_user_for_login(text) TO app_rw;
GRANT EXECUTE ON FUNCTION public.list_user_tenants(uuid) TO app_rw;

-- Catalog managed by migrations only
REVOKE INSERT, UPDATE, DELETE ON public.plans FROM app_rw;

-- Append-only for consumers
REVOKE UPDATE, DELETE ON public.audit_logs FROM app_rw;
