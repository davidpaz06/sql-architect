-- append-only.sql
-- Attaches prevent_mutation() to append-only tables.
CREATE OR REPLACE TRIGGER trg_audit_logs_append_only BEFORE UPDATE OR DELETE ON public.audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.prevent_mutation();
