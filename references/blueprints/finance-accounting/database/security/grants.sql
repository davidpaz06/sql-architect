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
GRANT EXECUTE ON FUNCTION public.post_journal_entry(date, text, jsonb, text) TO app_rw;
GRANT EXECUTE ON FUNCTION public.reverse_journal_entry(uuid, date, text) TO app_rw;

-- Catalogs managed by migrations only
REVOKE INSERT, UPDATE, DELETE ON public.currencies, public.account_types FROM app_rw;

-- The journal is written only through the functions above (definer); consumers read it.
REVOKE INSERT, UPDATE, DELETE ON public.journal_entries, public.journal_lines FROM app_rw;
