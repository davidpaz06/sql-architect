-- append-only.sql
-- Order lines are snapshots: never updated or deleted (corrections go through order status/refunds).
CREATE OR REPLACE TRIGGER trg_order_items_append_only BEFORE UPDATE OR DELETE ON public.order_items
  FOR EACH ROW EXECUTE FUNCTION public.prevent_mutation();
