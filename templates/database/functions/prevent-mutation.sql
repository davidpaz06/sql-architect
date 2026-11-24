-- prevent-mutation.sql
-- Shared trigger function for append-only tables (ledgers, audit logs): rejects UPDATE and DELETE.
CREATE OR REPLACE FUNCTION public.prevent_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION '% is append-only: % is not allowed', TG_TABLE_NAME, TG_OP
    USING ERRCODE = 'AP001';
END
$$;
