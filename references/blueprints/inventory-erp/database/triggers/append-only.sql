-- append-only.sql
-- The stock ledger is never updated or deleted; corrections are new adjustment movements.
CREATE OR REPLACE TRIGGER trg_stock_movements_append_only BEFORE UPDATE OR DELETE ON public.stock_movements
  FOR EACH ROW EXECUTE FUNCTION public.prevent_mutation();
