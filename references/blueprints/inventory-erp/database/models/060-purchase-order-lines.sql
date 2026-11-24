-- 060-purchase-order-lines.sql
-- Items and quantities ordered in a purchase order.
CREATE TABLE IF NOT EXISTS public.purchase_order_lines (
  id                 uuid          NOT NULL DEFAULT uuidv7(),
  purchase_order_id  uuid          NOT NULL,
  item_id            uuid          NOT NULL,
  quantity           numeric(14,3) NOT NULL,
  unit_cost          numeric(14,4) NOT NULL,
  created_at         timestamptz   NOT NULL DEFAULT now(),
  updated_at         timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT pk_purchase_order_lines PRIMARY KEY (id),
  CONSTRAINT fk_purchase_order_lines_purchase_order_id FOREIGN KEY (purchase_order_id)
    REFERENCES public.purchase_orders (id) ON DELETE CASCADE,
  CONSTRAINT fk_purchase_order_lines_item_id FOREIGN KEY (item_id) REFERENCES public.items (id) ON DELETE RESTRICT,
  CONSTRAINT uq_purchase_order_lines_purchase_order_id_item_id UNIQUE (purchase_order_id, item_id),
  CONSTRAINT ck_purchase_order_lines_quantity_positive CHECK (quantity > 0),
  CONSTRAINT ck_purchase_order_lines_unit_cost_non_negative CHECK (unit_cost >= 0)
);

CREATE INDEX IF NOT EXISTS idx_purchase_order_lines_item_id ON public.purchase_order_lines (item_id);

COMMENT ON TABLE public.purchase_order_lines IS 'Purchase order lines; one row per item';
