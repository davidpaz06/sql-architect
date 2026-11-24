-- append-only.sql
-- The journal is immutable: corrections are reversing entries.
CREATE OR REPLACE TRIGGER trg_journal_entries_append_only BEFORE UPDATE OR DELETE ON public.journal_entries
  FOR EACH ROW EXECUTE FUNCTION public.prevent_mutation();
CREATE OR REPLACE TRIGGER trg_journal_lines_append_only BEFORE UPDATE OR DELETE ON public.journal_lines
  FOR EACH ROW EXECUTE FUNCTION public.prevent_mutation();
