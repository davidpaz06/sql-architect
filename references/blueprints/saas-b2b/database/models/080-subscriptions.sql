-- 080-subscriptions.sql
-- Plan subscription of each tenant. At most one live subscription per tenant.
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id                    uuid        NOT NULL DEFAULT uuidv7(),
  tenant_id             uuid        NOT NULL,
  plan_id               integer     NOT NULL,
  status                text        NOT NULL DEFAULT 'trialing',
  current_period_start  timestamptz NOT NULL,
  current_period_end    timestamptz NOT NULL,
  cancelled_at          timestamptz NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_subscriptions PRIMARY KEY (id),
  CONSTRAINT fk_subscriptions_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.tenants (id) ON DELETE RESTRICT,
  CONSTRAINT fk_subscriptions_plan_id FOREIGN KEY (plan_id) REFERENCES public.plans (id) ON DELETE RESTRICT,
  CONSTRAINT ck_subscriptions_status CHECK (status IN ('trialing', 'active', 'past_due', 'cancelled')),
  CONSTRAINT ck_subscriptions_period CHECK (current_period_start < current_period_end)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_subscriptions_tenant_id_live
  ON public.subscriptions (tenant_id) WHERE status <> 'cancelled';
CREATE INDEX IF NOT EXISTS idx_subscriptions_plan_id ON public.subscriptions (plan_id);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE schemaname = 'public' AND tablename = 'subscriptions' AND policyname = 'tenant_isolation') THEN
    CREATE POLICY tenant_isolation ON public.subscriptions
      USING (tenant_id = public.current_tenant_id())
      WITH CHECK (tenant_id = public.current_tenant_id());
  END IF;
END $$;

COMMENT ON TABLE public.subscriptions IS 'Tenant plan subscriptions; history kept as cancelled rows';
