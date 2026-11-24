-- 010-plans.sql
-- Plans offered at launch. Conflicts on the natural key, never on the generated id.
INSERT INTO public.plans (code, name, monthly_price, currency_code, max_users) VALUES
  ('free',     'Free',     0.00,  'EUR', 3),
  ('pro',      'Pro',      29.00, 'EUR', 25),
  ('business', 'Business', 99.00, 'EUR', NULL)
ON CONFLICT (code) DO NOTHING;
