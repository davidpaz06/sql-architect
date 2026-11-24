-- 030-suppliers.sql
-- Suppliers that purchase orders are placed with.
CREATE TABLE IF NOT EXISTS public.suppliers (
  id          uuid        NOT NULL DEFAULT uuidv7(),
  name        text        NOT NULL,
  tax_id      text        NULL,
  email       text        NULL,
  phone       text        NULL,
  is_active   boolean     NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_suppliers PRIMARY KEY (id),
  CONSTRAINT uq_suppliers_tax_id UNIQUE (tax_id)
);

COMMENT ON TABLE public.suppliers IS 'Suppliers; tax_id unique when present';
