-- apply-stock-movement.sql
-- Trigger function: adds each new stock movement to stock_levels. Definer, because consumers can't write stock_levels.
CREATE OR REPLACE FUNCTION public.apply_stock_movement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  -- UPDATE first: INSERT … ON CONFLICT DO UPDATE would evaluate the CHECK on the proposed row
  -- (a negative quantity) before resolving the conflict, rejecting valid outbound movements.
  UPDATE public.stock_levels
  SET quantity = quantity + NEW.quantity
  WHERE item_id = NEW.item_id AND warehouse_id = NEW.warehouse_id;

  IF NOT FOUND THEN
    -- First movement for this item and warehouse. ON CONFLICT covers a concurrent first insert.
    -- A negative first movement fails ck_stock_levels_quantity_non_negative, as it should.
    INSERT INTO public.stock_levels AS s (item_id, warehouse_id, quantity)
    VALUES (NEW.item_id, NEW.warehouse_id, NEW.quantity)
    ON CONFLICT (item_id, warehouse_id) DO UPDATE SET quantity = s.quantity + EXCLUDED.quantity;
  END IF;
  RETURN NULL;
END
$$;
