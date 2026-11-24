-- 030-users.sql
-- People who can sign in. Global (a user may belong to several tenants through memberships).
CREATE TABLE IF NOT EXISTS public.users (
  id             uuid        NOT NULL DEFAULT uuidv7(),
  email          citext      NOT NULL,
  full_name      text        NOT NULL,
  password_hash  text        NULL,            -- hashed by the application; NULL for SSO-only users
  is_active      boolean     NOT NULL DEFAULT true,
  last_login_at  timestamptz NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_users PRIMARY KEY (id),
  CONSTRAINT uq_users_email UNIQUE (email)
);

-- RLS is enabled here; the visibility policy lives in 040-memberships.sql because it depends on that table.
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users FORCE ROW LEVEL SECURITY;

COMMENT ON TABLE public.users IS 'Global identities. Visible to a tenant only through memberships; written only by definer functions';
COMMENT ON COLUMN public.users.password_hash IS 'Argon2id/bcrypt hash produced by the application. Never plaintext';
