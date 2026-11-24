-- receive-purchase-order.sql
-- Receives an ordered purchase order in full: one receipt movement per line, status -> received.
-- Flow: docs/flows/purchase-order-receipt.md
CREATE OR REPLACE FUNCTION public.receive_purchase_order(p_purchase_order_id uuid)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_po     public.purchase_orders%ROWTYPE;
  v_lines  integer;
BEGIN
  SELECT * INTO v_po FROM public.purchase_orders po WHERE po.id = p_purchase_order_id FOR UPDATE;
  IF NOT FOUND OR v_po.status <> 'ordered' THEN
    RAISE EXCEPTION 'purchase order % is not in status ordered', p_purchase_order_id USING ERRCODE = 'AP301';
  END IF;

  INSERT INTO public.stock_movements (item_id, warehouse_id, kind, quantity, reference_type, reference_id)
  SELECT l.item_id, v_po.warehouse_id, 'receipt', l.quantity, 'purchase_order', v_po.id
  FROM public.purchase_order_lines l
  WHERE l.purchase_order_id = v_po.id;
  GET DIAGNOSTICS v_lines = ROW_COUNT;

  IF v_lines = 0 THEN
    RAISE EXCEPTION 'purchase order % has no lines', p_purchase_order_id USING ERRCODE = 'AP305';
  END IF;

  UPDATE public.purchase_orders SET status = 'received', received_at = now() WHERE id = v_po.id;
  RETURN v_lines;
END
$$;
