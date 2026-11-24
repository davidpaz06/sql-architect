-- 060-carts.sql
-- Shopping carts. Guest carts have no customer until checkout.
CREATE TABLE IF NOT EXISTS public.carts (
  id             uuid        NOT NULL DEFAULT uuidv7(),
  customer_id    uuid        NULL,
  status         text        NOT NULL DEFAULT 'open',
  currency_code  text        NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_carts PRIMARY KEY (id),
  CONSTRAINT fk_carts_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers (id) ON DELETE SET NULL,
  CONSTRAINT fk_carts_currency_code FOREIGN KEY (currency_code) REFERENCES public.currencies (code) ON DELETE RESTRICT,
  CONSTRAINT ck_carts_status CHECK (status IN ('open', 'converted', 'abandoned'))
);

CREATE INDEX IF NOT EXISTS idx_carts_customer_id ON public.carts (customer_id) WHERE customer_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_carts_currency_code ON public.carts (currency_code);

COMMENT ON TABLE public.carts IS 'Carts; converted by place_order(), abandoned by a cleanup job';
