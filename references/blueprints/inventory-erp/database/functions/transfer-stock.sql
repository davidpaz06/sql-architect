-- transfer-stock.sql
-- Moves a quantity of an item between two warehouses as a pair of movements sharing one reference.
-- Flow: docs/flows/stock-transfer.md
-- Definer: it must lock stock_levels (FOR UPDATE needs UPDATE privilege, which consumers don't have).
CREATE OR REPLACE FUNCTION public.transfer_stock(
  p_item_id            uuid,
  p_from_warehouse_id  uuid,
  p_to_warehouse_id    uuid,
  p_quantity           numeric,
  p_note               text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_available  numeric;
  v_transfer   uuid := uuidv7();
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'transfer quantity must be positive' USING ERRCODE = 'AP303';
  END IF;
  IF p_from_warehouse_id = p_to_warehouse_id THEN
    RAISE EXCEPTION 'source and destination warehouse are the same' USING ERRCODE = 'AP304';
  END IF;

  -- Lock the source level so concurrent issues/transfers see a consistent quantity
  SELECT s.quantity INTO v_available
  FROM public.stock_levels s
  WHERE s.item_id = p_item_id AND s.warehouse_id = p_from_warehouse_id
  FOR UPDATE;

  IF coalesce(v_available, 0) < p_quantity THEN
    RAISE EXCEPTION 'insufficient stock: % available, % requested', coalesce(v_available, 0), p_quantity
      USING ERRCODE = 'AP302';
  END IF;

  INSERT INTO public.stock_movements (item_id, warehouse_id, kind, quantity, reference_type, reference_id, note) VALUES
    (p_item_id, p_from_warehouse_id, 'transfer_out', -p_quantity, 'transfer', v_transfer, p_note),
    (p_item_id, p_to_warehouse_id,   'transfer_in',   p_quantity, 'transfer', v_transfer, p_note);

  RETURN v_transfer;
END
$$;
