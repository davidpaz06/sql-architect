-- 050-purchase-orders.sql
-- Purchase orders to suppliers, received into one warehouse.
CREATE TABLE IF NOT EXISTS public.purchase_orders (
  id            uuid        NOT NULL DEFAULT uuidv7(),
  number        bigint      GENERATED ALWAYS AS IDENTITY,
  supplier_id   uuid        NOT NULL,
  warehouse_id  uuid        NOT NULL,
  status        text        NOT NULL DEFAULT 'draft',
  ordered_on    date        NULL,
  expected_on   date        NULL,
  received_at   timestamptz NULL,
  notes         text        NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_purchase_orders PRIMARY KEY (id),
  CONSTRAINT uq_purchase_orders_number UNIQUE (number),
  CONSTRAINT fk_purchase_orders_supplier_id FOREIGN KEY (supplier_id) REFERENCES public.suppliers (id) ON DELETE RESTRICT,
  CONSTRAINT fk_purchase_orders_warehouse_id FOREIGN KEY (warehouse_id) REFERENCES public.warehouses (id) ON DELETE RESTRICT,
  CONSTRAINT ck_purchase_orders_status CHECK (status IN ('draft', 'ordered', 'received', 'cancelled')),
  CONSTRAINT ck_purchase_orders_received CHECK ((status = 'received') = (received_at IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_id ON public.purchase_orders (supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_warehouse_id ON public.purchase_orders (warehouse_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_open ON public.purchase_orders (expected_on) WHERE status = 'ordered';

COMMENT ON TABLE public.purchase_orders IS 'Purchase orders; received only through receive_purchase_order()';
