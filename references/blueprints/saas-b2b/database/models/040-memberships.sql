-- 040-memberships.sql
-- Links users to tenants with a role. Also defines which users a tenant can see.
CREATE TABLE IF NOT EXISTS public.memberships (
  id          uuid        NOT NULL DEFAULT uuidv7(),
  tenant_id   uuid        NOT NULL,
  user_id     uuid        NOT NULL,
  role        text        NOT NULL DEFAULT 'member',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_memberships PRIMARY KEY (id),
  CONSTRAINT fk_memberships_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.tenants (id) ON DELETE RESTRICT,
  CONSTRAINT fk_memberships_user_id FOREIGN KEY (user_id) REFERENCES public.users (id) ON DELETE RESTRICT,
  CONSTRAINT uq_memberships_tenant_id_user_id UNIQUE (tenant_id, user_id),
  CONSTRAINT ck_memberships_role CHECK (role IN ('owner', 'admin', 'member'))
);

CREATE INDEX IF NOT EXISTS idx_memberships_user_id ON public.memberships (user_id);

ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE schemaname = 'public' AND tablename = 'memberships' AND policyname = 'tenant_isolation') THEN
    CREATE POLICY tenant_isolation ON public.memberships
      USING (tenant_id = public.current_tenant_id())
      WITH CHECK (tenant_id = public.current_tenant_id());
  END IF;

  -- Policy on users: a tenant sees only the users that are its members (memberships is itself filtered by RLS).
  -- Read-only for consumers; users are written by definer functions.
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'member_visibility') THEN
    CREATE POLICY member_visibility ON public.users
      FOR SELECT
      USING (EXISTS (SELECT 1 FROM public.memberships m WHERE m.user_id = users.id));
  END IF;
END $$;

COMMENT ON TABLE public.memberships IS 'User ↔ tenant with role; the only path through which a tenant sees a user';
