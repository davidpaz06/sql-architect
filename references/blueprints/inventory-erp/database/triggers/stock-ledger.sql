-- stock-ledger.sql
-- Keeps stock_levels reconciled with every new stock movement (derived data, ADR-001).
CREATE OR REPLACE TRIGGER trg_stock_movements_apply AFTER INSERT ON public.stock_movements
  FOR EACH ROW EXECUTE FUNCTION public.apply_stock_movement();
