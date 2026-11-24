-- 010-plans.sql
-- Subscription plans offered by the SaaS. Small catalog managed by the team (identity key).
CREATE TABLE IF NOT EXISTS public.plans (
  id             integer     GENERATED ALWAYS AS IDENTITY,
  code           text        NOT NULL,
  name           text        NOT NULL,
  monthly_price  numeric(10,2) NOT NULL,
  currency_code  text        NOT NULL DEFAULT 'EUR',
  max_users      integer     NULL,            -- NULL = unlimited
  is_active      boolean     NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_plans PRIMARY KEY (id),
  CONSTRAINT uq_plans_code UNIQUE (code),
  CONSTRAINT ck_plans_monthly_price_non_negative CHECK (monthly_price >= 0),
  CONSTRAINT ck_plans_currency_code_iso CHECK (currency_code ~ '^[A-Z]{3}$'),
  CONSTRAINT ck_plans_max_users_positive CHECK (max_users IS NULL OR max_users > 0)
);

COMMENT ON TABLE public.plans IS 'Subscription plans; seeded by seeds/010-plans.sql';
COMMENT ON COLUMN public.plans.max_users IS 'Seat limit; NULL means unlimited';
