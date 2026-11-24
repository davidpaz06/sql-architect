-- 030-accounts.sql
-- Chart of accounts. Only postable (leaf) accounts receive journal lines; parents group them for reporting.
CREATE TABLE IF NOT EXISTS public.accounts (
  id               uuid        NOT NULL DEFAULT uuidv7(),
  code             text        NOT NULL,
  name             text        NOT NULL,
  account_type_id  integer     NOT NULL,
  parent_id        uuid        NULL,
  is_postable      boolean     NOT NULL DEFAULT true,
  is_active        boolean     NOT NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_accounts PRIMARY KEY (id),
  CONSTRAINT uq_accounts_code UNIQUE (code),
  CONSTRAINT fk_accounts_account_type_id FOREIGN KEY (account_type_id) REFERENCES public.account_types (id) ON DELETE RESTRICT,
  CONSTRAINT fk_accounts_parent_id FOREIGN KEY (parent_id) REFERENCES public.accounts (id) ON DELETE RESTRICT,
  CONSTRAINT ck_accounts_not_own_parent CHECK (parent_id <> id)
);

CREATE INDEX IF NOT EXISTS idx_accounts_account_type_id ON public.accounts (account_type_id);
CREATE INDEX IF NOT EXISTS idx_accounts_parent_id ON public.accounts (parent_id);

COMMENT ON TABLE public.accounts IS 'Chart of accounts; code follows the local accounting plan';
