-- 010-units.sql
-- Base units of measure.
INSERT INTO public.units (code, name) VALUES
  ('ea', 'Each'),
  ('kg', 'Kilogram'),
  ('l',  'Litre'),
  ('m',  'Metre'),
  ('box', 'Box')
ON CONFLICT (code) DO NOTHING;
