-- 020-account-types.sql
-- The five account types of double-entry bookkeeping.
INSERT INTO public.account_types (code, name, normal_balance) VALUES
  ('asset',     'Asset',     'debit'),
  ('liability', 'Liability', 'credit'),
  ('equity',    'Equity',    'credit'),
  ('revenue',   'Revenue',   'credit'),
  ('expense',   'Expense',   'debit')
ON CONFLICT (code) DO NOTHING;
