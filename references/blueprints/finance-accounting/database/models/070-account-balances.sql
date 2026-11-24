-- 070-account-balances.sql
-- Read model: balance per postable account, signed by the account type's normal side.
CREATE OR REPLACE VIEW public.account_balances AS
SELECT
  a.id                         AS account_id,
  a.code,
  a.name,
  t.code                       AS account_type,
  coalesce(sum(l.debit), 0)    AS debits,
  coalesce(sum(l.credit), 0)   AS credits,
  CASE t.normal_balance
    WHEN 'debit'  THEN coalesce(sum(l.debit), 0) - coalesce(sum(l.credit), 0)
    ELSE               coalesce(sum(l.credit), 0) - coalesce(sum(l.debit), 0)
  END                          AS balance
FROM public.accounts a
JOIN public.account_types t ON t.id = a.account_type_id
LEFT JOIN public.journal_lines l ON l.account_id = a.id
WHERE a.is_postable
GROUP BY a.id, a.code, a.name, t.code, t.normal_balance;

COMMENT ON VIEW public.account_balances IS 'All-time balances; filter journal lines by period for period reports';
