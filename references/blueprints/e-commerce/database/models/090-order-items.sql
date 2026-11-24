-- 090-order-items.sql
-- Order lines with product snapshot (sku, name, unit price). Append-only.
CREATE TABLE IF NOT EXISTS public.order_items (
  id          uuid          NOT NULL DEFAULT uuidv7(),
  order_id    uuid          NOT NULL,
  product_id  uuid          NOT NULL,
  sku         text          NOT NULL,
  name        text          NOT NULL,
  unit_price  numeric(12,2) NOT NULL,
  quantity    integer       NOT NULL,
  line_total  numeric(12,2) GENERATED ALWAYS AS (unit_price * quantity) STORED,
  created_at  timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT pk_order_items PRIMARY KEY (id),
  CONSTRAINT fk_order_items_order_id FOREIGN KEY (order_id) REFERENCES public.orders (id) ON DELETE RESTRICT,
  CONSTRAINT fk_order_items_product_id FOREIGN KEY (product_id) REFERENCES public.products (id) ON DELETE RESTRICT,
  CONSTRAINT ck_order_items_quantity_positive CHECK (quantity > 0),
  CONSTRAINT ck_order_items_unit_price_non_negative CHECK (unit_price >= 0)
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items (order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON public.order_items (product_id);

COMMENT ON TABLE public.order_items IS 'Immutable order lines; sku/name/unit_price are snapshots';
