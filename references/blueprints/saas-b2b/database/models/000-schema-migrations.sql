-- 000-schema-migrations.sql
-- Registry of applied migrations. Bootstrap fills it with the baseline; each migration registers itself.
CREATE TABLE IF NOT EXISTS public.schema_migrations (
  id          text        NOT NULL,
  applied_at  timestamptz NOT NULL DEFAULT now(),
  applied_by  text        NOT NULL DEFAULT current_user,
  CONSTRAINT pk_schema_migrations PRIMARY KEY (id)
);

COMMENT ON TABLE public.schema_migrations IS 'Applied migrations; id is the migration file name without .sql';
