-- 100-payments.sql
-- Payment attempts for an order, as reported by the payment provider.
CREATE TABLE IF NOT EXISTS public.payments (
  id              uuid          NOT NULL DEFAULT uuidv7(),
  order_id        uuid          NOT NULL,
  provider        text          NOT NULL,          -- e.g. 'stripe', 'pago_movil'
  provider_ref    text          NOT NULL,          -- provider's payment id; idempotency key for webhooks
  amount          numeric(12,2) NOT NULL,
  currency_code   text          NOT NULL,
  status          text          NOT NULL DEFAULT 'pending',
  created_at      timestamptz   NOT NULL DEFAULT now(),
  updated_at      timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT pk_payments PRIMARY KEY (id),
  CONSTRAINT fk_payments_order_id FOREIGN KEY (order_id) REFERENCES public.orders (id) ON DELETE RESTRICT,
  CONSTRAINT fk_payments_currency_code FOREIGN KEY (currency_code) REFERENCES public.currencies (code) ON DELETE RESTRICT,
  CONSTRAINT uq_payments_provider_provider_ref UNIQUE (provider, provider_ref),
  CONSTRAINT ck_payments_amount_positive CHECK (amount > 0),
  CONSTRAINT ck_payments_status CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded'))
);

CREATE INDEX IF NOT EXISTS idx_payments_order_id ON public.payments (order_id);
CREATE INDEX IF NOT EXISTS idx_payments_currency_code ON public.payments (currency_code);

COMMENT ON TABLE public.payments IS 'Payment attempts; (provider, provider_ref) makes webhook processing idempotent';
