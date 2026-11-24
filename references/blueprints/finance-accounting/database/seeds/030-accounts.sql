-- 030-accounts.sql
-- Minimal generic chart of accounts. Replace with the local plan (e.g. Spain's PGC) when adapting.
INSERT INTO public.accounts (code, name, account_type_id)
SELECT v.code, v.name, t.id
FROM (VALUES
  ('1000', 'Cash',                 'asset'),
  ('1100', 'Accounts receivable',  'asset'),
  ('2000', 'Accounts payable',     'liability'),
  ('2100', 'Taxes payable',        'liability'),
  ('3000', 'Owner equity',         'equity'),
  ('4000', 'Sales revenue',        'revenue'),
  ('5000', 'Operating expenses',   'expense')
) AS v(code, name, type_code)
JOIN public.account_types t ON t.code = v.type_code
ON CONFLICT (code) DO NOTHING;
