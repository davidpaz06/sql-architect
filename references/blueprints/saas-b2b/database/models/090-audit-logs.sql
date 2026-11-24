-- 090-audit-logs.sql
-- Append-only record of relevant actions per tenant. UPDATE/DELETE blocked by trigger and revoked.
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id              uuid        NOT NULL DEFAULT uuidv7(),
  tenant_id       uuid        NOT NULL,
  actor_user_id   uuid        NULL,             -- NULL for system actions
  action          text        NOT NULL,         -- e.g. 'tenant.registered', 'member.invited'
  entity          text        NULL,
  entity_id       uuid        NULL,
  payload         jsonb       NOT NULL DEFAULT '{}',
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_audit_logs PRIMARY KEY (id),
  CONSTRAINT fk_audit_logs_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.tenants (id) ON DELETE RESTRICT,
  CONSTRAINT fk_audit_logs_actor_user_id FOREIGN KEY (actor_user_id) REFERENCES public.users (id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant_id_created_at ON public.audit_logs (tenant_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_user_id ON public.audit_logs (actor_user_id) WHERE actor_user_id IS NOT NULL;

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE schemaname = 'public' AND tablename = 'audit_logs' AND policyname = 'tenant_isolation') THEN
    CREATE POLICY tenant_isolation ON public.audit_logs
      USING (tenant_id = public.current_tenant_id())
      WITH CHECK (tenant_id = public.current_tenant_id());
  END IF;
END $$;

COMMENT ON TABLE public.audit_logs IS 'Append-only audit trail; payload is free-form context (not queried by fields)';
