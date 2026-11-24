-- 080-orders.sql
-- Placed orders. Amounts and shipping address are snapshots taken at checkout.
CREATE TABLE IF NOT EXISTS public.orders (
  id              uuid          NOT NULL DEFAULT uuidv7(),
  number          bigint        GENERATED ALWAYS AS IDENTITY,   -- human-facing order number
  customer_id     uuid          NOT NULL,
  cart_id         uuid          NULL,
  status          text          NOT NULL DEFAULT 'pending_payment',
  currency_code   text          NOT NULL,
  subtotal        numeric(12,2) NOT NULL,
  shipping_total  numeric(12,2) NOT NULL DEFAULT 0,
  total           numeric(12,2) NOT NULL,
  ship_to         jsonb         NOT NULL,
  placed_at       timestamptz   NOT NULL DEFAULT now(),
  paid_at         timestamptz   NULL,
  cancelled_at    timestamptz   NULL,
  created_at      timestamptz   NOT NULL DEFAULT now(),
  updated_at      timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT pk_orders PRIMARY KEY (id),
  CONSTRAINT uq_orders_number UNIQUE (number),
  CONSTRAINT uq_orders_cart_id UNIQUE (cart_id),                  -- a cart becomes at most one order
  CONSTRAINT fk_orders_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers (id) ON DELETE RESTRICT,
  CONSTRAINT fk_orders_cart_id FOREIGN KEY (cart_id) REFERENCES public.carts (id) ON DELETE SET NULL,
  CONSTRAINT fk_orders_currency_code FOREIGN KEY (currency_code) REFERENCES public.currencies (code) ON DELETE RESTRICT,
  CONSTRAINT ck_orders_status CHECK (status IN ('pending_payment', 'paid', 'fulfilled', 'cancelled', 'refunded')),
  CONSTRAINT ck_orders_amounts CHECK (subtotal >= 0 AND shipping_total >= 0 AND total = subtotal + shipping_total)
);

CREATE INDEX IF NOT EXISTS idx_orders_customer_id_placed_at ON public.orders (customer_id, placed_at);
CREATE INDEX IF NOT EXISTS idx_orders_currency_code ON public.orders (currency_code);
CREATE INDEX IF NOT EXISTS idx_orders_pending ON public.orders (placed_at) WHERE status = 'pending_payment';

COMMENT ON TABLE public.orders IS 'Orders created by place_order(); never deleted, cancelled via status';
COMMENT ON COLUMN public.orders.ship_to IS 'Snapshot of the shipping address at checkout (history, not denormalization)';
