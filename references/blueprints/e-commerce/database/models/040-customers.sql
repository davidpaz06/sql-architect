-- 040-customers.sql
-- Store customers. password_hash is NULL for guest checkouts.
CREATE TABLE IF NOT EXISTS public.customers (
  id             uuid        NOT NULL DEFAULT uuidv7(),
  email          citext      NOT NULL,
  full_name      text        NOT NULL,
  phone          text        NULL,
  password_hash  text        NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_customers PRIMARY KEY (id),
  CONSTRAINT uq_customers_email UNIQUE (email)
);

COMMENT ON TABLE public.customers IS 'Registered and guest customers (guest = no password_hash)';
