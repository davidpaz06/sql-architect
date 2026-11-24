-- 010-currencies.sql
-- Currencies accepted at launch. Add more with a migration + this file.
INSERT INTO public.currencies (code, name, minor_units) VALUES
  ('EUR', 'Euro', 2),
  ('USD', 'US Dollar', 2)
ON CONFLICT (code) DO NOTHING;
