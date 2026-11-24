-- set-updated-at.sql
-- Shared BEFORE UPDATE trigger function that keeps updated_at current on every mutable table.
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END
$$;
