-- 010-units.sql
-- Units of measure. Small catalog managed by migrations (identity key, seeded).
CREATE TABLE IF NOT EXISTS public.units (
  id          integer     GENERATED ALWAYS AS IDENTITY,
  code        text        NOT NULL,
  name        text        NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_units PRIMARY KEY (id),
  CONSTRAINT uq_units_code UNIQUE (code)
);

COMMENT ON TABLE public.units IS 'Units of measure; seeded by seeds/010-units.sql';
