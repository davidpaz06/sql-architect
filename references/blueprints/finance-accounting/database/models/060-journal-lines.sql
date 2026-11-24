-- 060-journal-lines.sql
-- Debit/credit lines of a journal entry. Each line is either a debit or a credit, never both.
CREATE TABLE IF NOT EXISTS public.journal_lines (
  id                uuid          NOT NULL DEFAULT uuidv7(),
  journal_entry_id  uuid          NOT NULL,
  line_no           smallint      NOT NULL,
  account_id        uuid          NOT NULL,
  debit             numeric(19,4) NOT NULL DEFAULT 0,
  credit            numeric(19,4) NOT NULL DEFAULT 0,
  description       text          NULL,
  created_at        timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT pk_journal_lines PRIMARY KEY (id),
  CONSTRAINT fk_journal_lines_journal_entry_id FOREIGN KEY (journal_entry_id)
    REFERENCES public.journal_entries (id) ON DELETE RESTRICT,
  CONSTRAINT fk_journal_lines_account_id FOREIGN KEY (account_id) REFERENCES public.accounts (id) ON DELETE RESTRICT,
  CONSTRAINT uq_journal_lines_journal_entry_id_line_no UNIQUE (journal_entry_id, line_no),
  CONSTRAINT ck_journal_lines_one_side CHECK (debit >= 0 AND credit >= 0 AND ((debit > 0) <> (credit > 0)))
);

CREATE INDEX IF NOT EXISTS idx_journal_lines_account_id ON public.journal_lines (account_id);

COMMENT ON TABLE public.journal_lines IS 'Immutable entry lines; per entry, sum(debit) = sum(credit) (enforced by post_journal_entry)';
