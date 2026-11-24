-- 070-stock-movements.sql
-- Append-only stock ledger: every change of stock is a signed movement. Source of truth for quantities.
CREATE TABLE IF NOT EXISTS public.stock_movements (
  id              uuid          NOT NULL DEFAULT uuidv7(),
  item_id         uuid          NOT NULL,
  warehouse_id    uuid          NOT NULL,
  kind            text          NOT NULL,
  quantity        numeric(14,3) NOT NULL,        -- positive = in, negative = out
  reference_type  text          NULL,            -- e.g. 'purchase_order', 'transfer', 'sales_order'
  reference_id    uuid          NULL,
  note            text          NULL,
  occurred_at     timestamptz   NOT NULL DEFAULT now(),
  created_at      timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT pk_stock_movements PRIMARY KEY (id),
  CONSTRAINT fk_stock_movements_item_id FOREIGN KEY (item_id) REFERENCES public.items (id) ON DELETE RESTRICT,
  CONSTRAINT fk_stock_movements_warehouse_id FOREIGN KEY (warehouse_id) REFERENCES public.warehouses (id) ON DELETE RESTRICT,
  CONSTRAINT ck_stock_movements_kind CHECK (kind IN ('receipt', 'issue', 'transfer_in', 'transfer_out', 'adjustment')),
  CONSTRAINT ck_stock_movements_sign CHECK (
    (kind IN ('receipt', 'transfer_in') AND quantity > 0) OR
    (kind IN ('issue', 'transfer_out') AND quantity < 0) OR
    (kind = 'adjustment' AND quantity <> 0)
  )
);

CREATE INDEX IF NOT EXISTS idx_stock_movements_item_id_warehouse_id_occurred_at
  ON public.stock_movements (item_id, warehouse_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_stock_movements_warehouse_id ON public.stock_movements (warehouse_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_reference ON public.stock_movements (reference_type, reference_id)
  WHERE reference_id IS NOT NULL;

COMMENT ON TABLE public.stock_movements IS 'Immutable stock ledger. stock_levels is derived from it (ADR-001)';
