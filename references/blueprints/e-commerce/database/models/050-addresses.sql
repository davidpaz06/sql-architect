-- 050-addresses.sql
-- Shipping addresses of a customer. Orders copy the address (snapshot), so editing it never alters history.
CREATE TABLE IF NOT EXISTS public.addresses (
  id              uuid        NOT NULL DEFAULT uuidv7(),
  customer_id     uuid        NOT NULL,
  recipient_name  text        NOT NULL,
  line1           text        NOT NULL,
  line2           text        NULL,
  city            text        NOT NULL,
  region          text        NULL,
  postal_code     text        NULL,
  country_code    text        NOT NULL,
  is_default      boolean     NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_addresses PRIMARY KEY (id),
  CONSTRAINT fk_addresses_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers (id) ON DELETE CASCADE,
  CONSTRAINT ck_addresses_country_code_iso CHECK (country_code ~ '^[A-Z]{2}$')
);

CREATE INDEX IF NOT EXISTS idx_addresses_customer_id ON public.addresses (customer_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_addresses_customer_id_default
  ON public.addresses (customer_id) WHERE is_default;

COMMENT ON TABLE public.addresses IS 'Customer address book; at most one default per customer';
