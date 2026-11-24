-- 020-warehouses.sql
-- Physical or logical stock locations.
CREATE TABLE IF NOT EXISTS public.warehouses (
  id          uuid        NOT NULL DEFAULT uuidv7(),
  code        text        NOT NULL,
  name        text        NOT NULL,
  address     text        NULL,
  is_active   boolean     NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_warehouses PRIMARY KEY (id),
  CONSTRAINT uq_warehouses_code UNIQUE (code)
);

COMMENT ON TABLE public.warehouses IS 'Stock locations';
