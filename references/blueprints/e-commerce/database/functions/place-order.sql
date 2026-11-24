-- place-order.sql
-- Checkout: turns an open cart into an order, snapshots prices and address, and reserves stock atomically.
-- Flow: docs/flows/checkout.md
CREATE OR REPLACE FUNCTION public.place_order(
  p_cart_id         uuid,
  p_customer_id     uuid,
  p_address_id      uuid,
  p_shipping_total  numeric DEFAULT 0
)
RETURNS TABLE (order_id uuid, order_number bigint)
LANGUAGE plpgsql
AS $$
DECLARE
  v_cart      public.carts%ROWTYPE;
  v_address   public.addresses%ROWTYPE;
  v_line      record;
  v_subtotal  numeric(12,2) := 0;
  v_order_id  uuid;
  v_number    bigint;
BEGIN
  SELECT * INTO v_cart FROM public.carts c WHERE c.id = p_cart_id FOR UPDATE;
  IF NOT FOUND OR v_cart.status <> 'open' THEN
    RAISE EXCEPTION 'cart % is not open', p_cart_id USING ERRCODE = 'AP103';
  END IF;

  SELECT * INTO v_address FROM public.addresses a WHERE a.id = p_address_id AND a.customer_id = p_customer_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'address does not belong to the customer' USING ERRCODE = 'AP105';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.cart_items ci WHERE ci.cart_id = p_cart_id) THEN
    RAISE EXCEPTION 'cart % is empty', p_cart_id USING ERRCODE = 'AP101';
  END IF;

  -- Lock the products in a fixed order (by id) so concurrent checkouts can't deadlock,
  -- then validate stock, currency and availability.
  FOR v_line IN
    SELECT p.id, p.sku, p.price, p.currency_code, p.stock_quantity, p.is_active, ci.quantity
    FROM public.cart_items ci
    JOIN public.products p ON p.id = ci.product_id
    WHERE ci.cart_id = p_cart_id
    ORDER BY p.id
    FOR UPDATE OF p
  LOOP
    IF NOT v_line.is_active THEN
      RAISE EXCEPTION 'product % is no longer available', v_line.sku USING ERRCODE = 'AP106';
    END IF;
    IF v_line.currency_code <> v_cart.currency_code THEN
      RAISE EXCEPTION 'product % is priced in %, cart is in %', v_line.sku, v_line.currency_code, v_cart.currency_code
        USING ERRCODE = 'AP104';
    END IF;
    IF v_line.stock_quantity < v_line.quantity THEN
      RAISE EXCEPTION 'insufficient stock for %: % available, % requested', v_line.sku, v_line.stock_quantity, v_line.quantity
        USING ERRCODE = 'AP102';
    END IF;
    v_subtotal := v_subtotal + v_line.price * v_line.quantity;
  END LOOP;

  INSERT INTO public.orders (customer_id, cart_id, currency_code, subtotal, shipping_total, total, ship_to)
  VALUES (
    p_customer_id, p_cart_id, v_cart.currency_code, v_subtotal, p_shipping_total, v_subtotal + p_shipping_total,
    jsonb_build_object(
      'recipient_name', v_address.recipient_name, 'line1', v_address.line1, 'line2', v_address.line2,
      'city', v_address.city, 'region', v_address.region, 'postal_code', v_address.postal_code,
      'country_code', v_address.country_code)
  )
  RETURNING id, number INTO v_order_id, v_number;

  INSERT INTO public.order_items (order_id, product_id, sku, name, unit_price, quantity)
  SELECT v_order_id, p.id, p.sku, p.name, p.price, ci.quantity
  FROM public.cart_items ci JOIN public.products p ON p.id = ci.product_id
  WHERE ci.cart_id = p_cart_id;

  UPDATE public.products p
  SET stock_quantity = p.stock_quantity - ci.quantity
  FROM public.cart_items ci
  WHERE ci.cart_id = p_cart_id AND ci.product_id = p.id;

  UPDATE public.carts SET status = 'converted', customer_id = p_customer_id WHERE id = p_cart_id;

  RETURN QUERY SELECT v_order_id, v_number;
END
$$;
