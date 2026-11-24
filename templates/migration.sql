-- MIG-000-concept-in-kebab-case-YYYYMMDDHHmm.sql
-- One to three lines: what changes and why (link the flow or ADR if there is one).

-- Guard: skip the whole file if it was already applied (bootstrap baseline or an earlier run).
SELECT EXISTS (
  SELECT 1 FROM public.schema_migrations WHERE id = 'MIG-000-concept-in-kebab-case-YYYYMMDDHHmm'
) AS already_applied \gset
\if :already_applied
  \echo 'skip MIG-000-concept-in-kebab-case-YYYYMMDDHHmm (already applied)'
  \quit
\endif

BEGIN;
SET LOCAL ROLE app_owner;            -- new objects belong to the owner, whoever runs the file
SET LOCAL lock_timeout = '5s';       -- fail fast instead of queueing behind long transactions
SET LOCAL statement_timeout = '60s';

-- Statements, each idempotent on its own:
-- ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone text;

INSERT INTO public.schema_migrations (id)
VALUES ('MIG-000-concept-in-kebab-case-YYYYMMDDHHmm')
ON CONFLICT (id) DO NOTHING;

COMMIT;
