-- post-journal-entry.sql
-- Posts a balanced journal entry into an open period. The only way consumers write to the journal.
-- Flow: docs/flows/journal-entry-posting.md
CREATE OR REPLACE FUNCTION public.post_journal_entry(
  p_entry_on       date,
  p_memo           text,
  p_lines          jsonb,          -- [{"account_id": "<uuid>", "debit": 100.00, "credit": 0, "description": "..."}]
  p_currency_code  text DEFAULT 'EUR'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_period_id  uuid;
  v_entry_id   uuid;
  v_invalid    boolean;
  v_debits     numeric;
  v_credits    numeric;
BEGIN
  IF jsonb_typeof(p_lines) IS DISTINCT FROM 'array' OR jsonb_array_length(p_lines) < 2 THEN
    RAISE EXCEPTION 'a journal entry needs at least two lines' USING ERRCODE = 'AP201';
  END IF;

  SELECT bool_or(x.account_id IS NULL
                 OR coalesce(x.debit, 0) < 0 OR coalesce(x.credit, 0) < 0
                 OR (coalesce(x.debit, 0) > 0) = (coalesce(x.credit, 0) > 0)),
         sum(coalesce(x.debit, 0)), sum(coalesce(x.credit, 0))
  INTO v_invalid, v_debits, v_credits
  FROM jsonb_to_recordset(p_lines) AS x(account_id uuid, debit numeric, credit numeric);

  IF v_invalid THEN
    RAISE EXCEPTION 'each line needs an account and exactly one positive amount (debit or credit)'
      USING ERRCODE = 'AP206';
  END IF;
  IF v_debits <> v_credits THEN
    RAISE EXCEPTION 'entry is unbalanced: debits % <> credits %', v_debits, v_credits USING ERRCODE = 'AP202';
  END IF;

  IF EXISTS (SELECT 1
             FROM jsonb_to_recordset(p_lines) AS x(account_id uuid)
             LEFT JOIN public.accounts a ON a.id = x.account_id
             WHERE a.id IS NULL OR NOT a.is_postable OR NOT a.is_active) THEN
    RAISE EXCEPTION 'every line must use an existing, active, postable account' USING ERRCODE = 'AP204';
  END IF;

  -- FOR SHARE: a concurrent period close (UPDATE) waits until this entry commits
  SELECT p.id INTO v_period_id
  FROM public.fiscal_periods p
  WHERE p.period @> p_entry_on AND p.status = 'open'
  FOR SHARE;
  IF v_period_id IS NULL THEN
    RAISE EXCEPTION 'no open fiscal period contains %', p_entry_on USING ERRCODE = 'AP203';
  END IF;

  INSERT INTO public.journal_entries (entry_on, fiscal_period_id, currency_code, memo)
  VALUES (p_entry_on, v_period_id, p_currency_code, p_memo)
  RETURNING id INTO v_entry_id;

  INSERT INTO public.journal_lines (journal_entry_id, line_no, account_id, debit, credit, description)
  SELECT v_entry_id, x.ord::smallint, x.account_id, coalesce(x.debit, 0), coalesce(x.credit, 0), x.description
  FROM ROWS FROM (jsonb_to_recordset(p_lines) AS (account_id uuid, debit numeric, credit numeric, description text))
       WITH ORDINALITY AS x(account_id, debit, credit, description, ord);

  RETURN v_entry_id;
END
$$;
