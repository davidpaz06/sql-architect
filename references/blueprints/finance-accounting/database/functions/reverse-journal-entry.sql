-- reverse-journal-entry.sql
-- Corrects a posted entry by posting its mirror image (debits <-> credits) into an open period.
-- Flow: docs/flows/journal-entry-posting.md
CREATE OR REPLACE FUNCTION public.reverse_journal_entry(
  p_journal_entry_id  uuid,
  p_entry_on          date,
  p_memo              text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_original   public.journal_entries%ROWTYPE;
  v_period_id  uuid;
  v_entry_id   uuid;
BEGIN
  SELECT * INTO v_original FROM public.journal_entries e WHERE e.id = p_journal_entry_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'journal entry % does not exist', p_journal_entry_id USING ERRCODE = 'AP207';
  END IF;
  IF EXISTS (SELECT 1 FROM public.journal_entries e WHERE e.reverses_entry_id = p_journal_entry_id) THEN
    RAISE EXCEPTION 'journal entry % is already reversed', v_original.number USING ERRCODE = 'AP205';
  END IF;

  SELECT p.id INTO v_period_id
  FROM public.fiscal_periods p
  WHERE p.period @> p_entry_on AND p.status = 'open'
  FOR SHARE;
  IF v_period_id IS NULL THEN
    RAISE EXCEPTION 'no open fiscal period contains %', p_entry_on USING ERRCODE = 'AP203';
  END IF;

  -- uq_journal_entries_reverses_entry_id rejects a concurrent second reversal (23505)
  INSERT INTO public.journal_entries (entry_on, fiscal_period_id, currency_code, memo, reverses_entry_id)
  VALUES (p_entry_on, v_period_id, v_original.currency_code,
          coalesce(p_memo, 'Reversal of entry ' || v_original.number), v_original.id)
  RETURNING id INTO v_entry_id;

  INSERT INTO public.journal_lines (journal_entry_id, line_no, account_id, debit, credit, description)
  SELECT v_entry_id, l.line_no, l.account_id, l.credit, l.debit, l.description
  FROM public.journal_lines l
  WHERE l.journal_entry_id = v_original.id;

  RETURN v_entry_id;
END
$$;
