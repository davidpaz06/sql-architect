-- 080-stock-levels.sql
-- Current quantity per item and warehouse: cached aggregate of stock_movements, maintained by trigger (ADR-001).
CREATE TABLE IF NOT EXISTS public.stock_levels (
  item_id       uuid          NOT NULL,
  warehouse_id  uuid          NOT NULL,
  quantity      numeric(14,3) NOT NULL DEFAULT 0,
  created_at    timestamptz   NOT NULL DEFAULT now(),
  updated_at    timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT pk_stock_levels PRIMARY KEY (item_id, warehouse_id),
  CONSTRAINT fk_stock_levels_item_id FOREIGN KEY (item_id) REFERENCES public.items (id) ON DELETE RESTRICT,
  CONSTRAINT fk_stock_levels_warehouse_id FOREIGN KEY (warehouse_id) REFERENCES public.warehouses (id) ON DELETE RESTRICT,
  CONSTRAINT ck_stock_levels_quantity_non_negative CHECK (quantity >= 0)
);

CREATE INDEX IF NOT EXISTS idx_stock_levels_warehouse_id ON public.stock_levels (warehouse_id);

COMMENT ON TABLE public.stock_levels IS 'Derived from stock_movements by trg_stock_movements_apply; read-only for consumers (ADR-001)';
