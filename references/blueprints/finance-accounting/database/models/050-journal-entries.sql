-- 050-journal-entries.sql
-- Journal entry headers. Immutable once posted: corrections are reversing entries.
CREATE TABLE IF NOT EXISTS public.journal_entries (
  id                 uuid        NOT NULL DEFAULT uuidv7(),
  number             bigint      GENERATED ALWAYS AS IDENTITY,
  entry_on           date        NOT NULL,
  fiscal_period_id   uuid        NOT NULL,
  currency_code      text        NOT NULL,
  memo               text        NOT NULL,
  reverses_entry_id  uuid        NULL,
  posted_at          timestamptz NOT NULL DEFAULT now(),
  created_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_journal_entries PRIMARY KEY (id),
  CONSTRAINT uq_journal_entries_number UNIQUE (number),
  CONSTRAINT uq_journal_entries_reverses_entry_id UNIQUE (reverses_entry_id),   -- an entry is reversed at most once
  CONSTRAINT fk_journal_entries_fiscal_period_id FOREIGN KEY (fiscal_period_id)
    REFERENCES public.fiscal_periods (id) ON DELETE RESTRICT,
  CONSTRAINT fk_journal_entries_currency_code FOREIGN KEY (currency_code)
    REFERENCES public.currencies (code) ON DELETE RESTRICT,
  CONSTRAINT fk_journal_entries_reverses_entry_id FOREIGN KEY (reverses_entry_id)
    REFERENCES public.journal_entries (id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_journal_entries_fiscal_period_id ON public.journal_entries (fiscal_period_id);
CREATE INDEX IF NOT EXISTS idx_journal_entries_entry_on ON public.journal_entries (entry_on);
CREATE INDEX IF NOT EXISTS idx_journal_entries_currency_code ON public.journal_entries (currency_code);

COMMENT ON TABLE public.journal_entries IS 'Posted journal entries; written only by post_journal_entry()/reverse_journal_entry()';
