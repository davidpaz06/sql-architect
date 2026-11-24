-- 020-tenants.sql
-- Customer organizations. Root of the tenancy model; each tenant only sees its own row.
CREATE TABLE IF NOT EXISTS public.tenants (
  id          uuid        NOT NULL DEFAULT uuidv7(),
  name        text        NOT NULL,
  slug        text        NOT NULL,
  status      text        NOT NULL DEFAULT 'active',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_tenants PRIMARY KEY (id),
  CONSTRAINT uq_tenants_slug UNIQUE (slug),
  CONSTRAINT ck_tenants_slug_format CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  CONSTRAINT ck_tenants_status CHECK (status IN ('active', 'suspended', 'cancelled'))
);

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenants FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE schemaname = 'public' AND tablename = 'tenants' AND policyname = 'tenant_self') THEN
    CREATE POLICY tenant_self ON public.tenants
      USING (id = public.current_tenant_id())
      WITH CHECK (id = public.current_tenant_id());
  END IF;
END $$;

COMMENT ON TABLE public.tenants IS 'Customer organizations. Created only through register_tenant(); never hard-deleted (status)';
