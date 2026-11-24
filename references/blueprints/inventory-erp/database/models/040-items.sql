-- 040-items.sql
-- Items managed in inventory (raw materials, goods for resale, consumables).
CREATE TABLE IF NOT EXISTS public.items (
  id             uuid          NOT NULL DEFAULT uuidv7(),
  sku            text          NOT NULL,
  name           text          NOT NULL,
  unit_id        integer       NOT NULL,
  standard_cost  numeric(14,4) NOT NULL DEFAULT 0,
  reorder_point  numeric(14,3) NOT NULL DEFAULT 0,
  is_active      boolean       NOT NULL DEFAULT true,
  created_at     timestamptz   NOT NULL DEFAULT now(),
  updated_at     timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT pk_items PRIMARY KEY (id),
  CONSTRAINT fk_items_unit_id FOREIGN KEY (unit_id) REFERENCES public.units (id) ON DELETE RESTRICT,
  CONSTRAINT uq_items_sku UNIQUE (sku),
  CONSTRAINT ck_items_standard_cost_non_negative CHECK (standard_cost >= 0),
  CONSTRAINT ck_items_reorder_point_non_negative CHECK (reorder_point >= 0)
);

CREATE INDEX IF NOT EXISTS idx_items_unit_id ON public.items (unit_id);

COMMENT ON TABLE public.items IS 'Inventory items; quantities are in the item unit with 3 decimals';
