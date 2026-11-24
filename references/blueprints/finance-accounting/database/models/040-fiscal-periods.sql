-- 040-fiscal-periods.sql
-- Accounting periods. Entries can only be posted into an open period; periods never overlap.
CREATE TABLE IF NOT EXISTS public.fiscal_periods (
  id          uuid        NOT NULL DEFAULT uuidv7(),
  name        text        NOT NULL,            -- e.g. '2026-11'
  period      daterange   NOT NULL,            -- [first day, first day of next period)
  status      text        NOT NULL DEFAULT 'open',
  closed_at   timestamptz NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_fiscal_periods PRIMARY KEY (id),
  CONSTRAINT uq_fiscal_periods_name UNIQUE (name),
  CONSTRAINT ex_fiscal_periods_period EXCLUDE USING gist (period WITH &&),
  CONSTRAINT ck_fiscal_periods_period_bounded CHECK (NOT isempty(period) AND NOT lower_inf(period) AND NOT upper_inf(period)),
  CONSTRAINT ck_fiscal_periods_status CHECK (status IN ('open', 'closed')),
  CONSTRAINT ck_fiscal_periods_closed CHECK ((status = 'closed') = (closed_at IS NOT NULL))
);

COMMENT ON TABLE public.fiscal_periods IS 'Non-overlapping accounting periods (exclusion constraint)';
