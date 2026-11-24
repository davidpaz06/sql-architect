-- MIG-000-concept-in-kebab-case-YYYYMMDDHHmm.sql
-- One to three lines: what changes and why.
-- no-transaction
-- Contains a statement that cannot run inside a transaction block (CREATE INDEX CONCURRENTLY, …).
-- Keep exactly one such statement per file, so a failure leaves nothing half-done.

SELECT EXISTS (
  SELECT 1 FROM public.schema_migrations WHERE id = 'MIG-000-concept-in-kebab-case-YYYYMMDDHHmm'
) AS already_applied \gset
\if :already_applied
  \echo 'skip MIG-000-concept-in-kebab-case-YYYYMMDDHHmm (already applied)'
  \quit
\endif

SET ROLE app_owner;
SET lock_timeout = '5s';
SET statement_timeout = 0;           -- concurrent builds can take long; they do not block writes

-- A failed concurrent build leaves an INVALID index that IF NOT EXISTS would silently keep: drop it first.
SELECT EXISTS (
  SELECT 1 FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
  WHERE c.relname = 'idx_orders_customer_id_created_at' AND NOT i.indisvalid
) AS invalid_index \gset
\if :invalid_index
  DROP INDEX CONCURRENTLY public.idx_orders_customer_id_created_at;
\endif

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_customer_id_created_at
  ON public.orders (customer_id, created_at);

INSERT INTO public.schema_migrations (id)
VALUES ('MIG-000-concept-in-kebab-case-YYYYMMDDHHmm')
ON CONFLICT (id) DO NOTHING;

RESET ROLE;
