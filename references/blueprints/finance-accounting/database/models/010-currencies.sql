-- 010-currencies.sql
-- ISO 4217 currencies used in the books. Immutable natural code as primary key.
CREATE TABLE IF NOT EXISTS public.currencies (
  code         text        NOT NULL,
  name         text        NOT NULL,
  minor_units  smallint    NOT NULL DEFAULT 2,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_currencies PRIMARY KEY (code),
  CONSTRAINT ck_currencies_code_iso CHECK (code ~ '^[A-Z]{3}$'),
  CONSTRAINT ck_currencies_minor_units CHECK (minor_units BETWEEN 0 AND 4)
);

COMMENT ON TABLE public.currencies IS 'ISO 4217 currencies; seeded by seeds/010-currencies.sql';
