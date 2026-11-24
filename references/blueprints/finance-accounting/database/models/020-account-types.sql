-- 020-account-types.sql
-- The five fundamental account types and their normal balance side (identity catalog, seeded).
CREATE TABLE IF NOT EXISTS public.account_types (
  id              integer     GENERATED ALWAYS AS IDENTITY,
  code            text        NOT NULL,
  name            text        NOT NULL,
  normal_balance  text        NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_account_types PRIMARY KEY (id),
  CONSTRAINT uq_account_types_code UNIQUE (code),
  CONSTRAINT ck_account_types_normal_balance CHECK (normal_balance IN ('debit', 'credit'))
);

COMMENT ON TABLE public.account_types IS 'asset, liability, equity, revenue, expense; seeded by seeds/020-account-types.sql';
