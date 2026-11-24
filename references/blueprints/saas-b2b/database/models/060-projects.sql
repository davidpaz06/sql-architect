-- 060-projects.sql
-- Example domain entity owned by a tenant. Replace or extend with the product's real entities.
CREATE TABLE IF NOT EXISTS public.projects (
  id           uuid        NOT NULL DEFAULT uuidv7(),
  tenant_id    uuid        NOT NULL,
  name         text        NOT NULL,
  description  text        NULL,
  status       text        NOT NULL DEFAULT 'active',
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_projects PRIMARY KEY (id),
  CONSTRAINT fk_projects_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.tenants (id) ON DELETE RESTRICT,
  CONSTRAINT uq_projects_tenant_id_id UNIQUE (tenant_id, id),          -- target of composite FKs from children
  CONSTRAINT uq_projects_tenant_id_name UNIQUE (tenant_id, name),
  CONSTRAINT ck_projects_status CHECK (status IN ('active', 'archived'))
);

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE schemaname = 'public' AND tablename = 'projects' AND policyname = 'tenant_isolation') THEN
    CREATE POLICY tenant_isolation ON public.projects
      USING (tenant_id = public.current_tenant_id())
      WITH CHECK (tenant_id = public.current_tenant_id());
  END IF;
END $$;

COMMENT ON TABLE public.projects IS 'Example tenant-owned entity';
