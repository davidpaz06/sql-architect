-- 050-invitations.sql
-- Pending invitations to join a tenant. The token is stored hashed; acceptance goes through accept_invitation().
CREATE TABLE IF NOT EXISTS public.invitations (
  id                  uuid        NOT NULL DEFAULT uuidv7(),
  tenant_id           uuid        NOT NULL,
  email               citext      NOT NULL,
  role                text        NOT NULL DEFAULT 'member',
  token_hash          text        NOT NULL,
  invited_by_user_id  uuid        NOT NULL,
  expires_at          timestamptz NOT NULL,
  accepted_at         timestamptz NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_invitations PRIMARY KEY (id),
  CONSTRAINT fk_invitations_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.tenants (id) ON DELETE RESTRICT,
  CONSTRAINT fk_invitations_invited_by_user_id FOREIGN KEY (invited_by_user_id) REFERENCES public.users (id) ON DELETE RESTRICT,
  CONSTRAINT uq_invitations_token_hash UNIQUE (token_hash),
  CONSTRAINT ck_invitations_role CHECK (role IN ('admin', 'member'))
);

-- One pending invitation per email and tenant
CREATE UNIQUE INDEX IF NOT EXISTS uq_invitations_tenant_id_email_pending
  ON public.invitations (tenant_id, email) WHERE accepted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_invitations_invited_by_user_id ON public.invitations (invited_by_user_id);

ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitations FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE schemaname = 'public' AND tablename = 'invitations' AND policyname = 'tenant_isolation') THEN
    CREATE POLICY tenant_isolation ON public.invitations
      USING (tenant_id = public.current_tenant_id())
      WITH CHECK (tenant_id = public.current_tenant_id());
  END IF;
END $$;

COMMENT ON TABLE public.invitations IS 'Invitations to join a tenant; token_hash = hash of the emailed token (the token itself is never stored)';
