# Journal entry posting

## Purpose

Record a financial event as a balanced double-entry journal entry, and correct mistakes by reversal, never by editing.

## Actors and roles

Accounting staff or other modules (invoicing, payroll) via the consumer as `app_api` / `app_worker` (`app_rw`). Writes go only through the two `SECURITY DEFINER` functions.

## Steps

Posting — `post_journal_entry(entry_on, memo, lines, currency_code)`:
1. Validates the lines array: at least two lines; each with an account and exactly one positive amount.
2. Checks total debits = total credits.
3. Checks every account exists, is active and postable.
4. Finds the open period containing `entry_on` and takes a share lock on it.
5. Inserts the header and the numbered lines; returns the entry id.

Reversal — `reverse_journal_entry(entry_id, entry_on, memo)`:
1. Checks the entry exists and has not been reversed.
2. Finds an open period for the reversal date (may differ from the original's, which may be closed).
3. Inserts a header with `reverses_entry_id` and the lines with debit and credit swapped.

## Invariants

- Every entry balances (function validation; consumers can't insert directly).
- Each line is a debit or a credit, never both or neither (CHECK).
- Posted entries and lines never change (append-only triggers + revoked privileges).
- Nothing is posted into a closed period or a date outside every period.
- An entry is reversed at most once (unique `reverses_entry_id`).
- Periods never overlap (exclusion constraint).

## Implementation

- `public.post_journal_entry(p_entry_on date, p_memo text, p_lines jsonb, p_currency_code text DEFAULT 'EUR') RETURNS uuid`
  where `p_lines` = `[{"account_id": "<uuid>", "debit": 100.00, "description": "…"}, {"account_id": "<uuid>", "credit": 100.00}]`
- `public.reverse_journal_entry(p_journal_entry_id uuid, p_entry_on date, p_memo text DEFAULT NULL) RETURNS uuid`

## Errors

| SQLSTATE | Condition | Meaning for the consumer |
|---|---|---|
| AP201 | Fewer than two lines | Client error |
| AP202 | Debits ≠ credits | Show both totals |
| AP203 | No open period for the date | Pick another date or reopen the period |
| AP204 | Unknown, inactive or non-postable account | Client/configuration error |
| AP205 | Entry already reversed | Idempotent retry: fetch the existing reversal |
| AP206 | A line has both, neither or negative amounts | Client error |
| AP207 | Entry to reverse not found | Client error |
| 23505 | Concurrent second reversal | Same as AP205 |

## Concurrency

Closing a period is an `UPDATE fiscal_periods SET status = 'closed', closed_at = now()`: it waits for in-flight postings holding the share lock, and later postings find no open period. Entry numbers come from an identity: gaps are possible after rollbacks (legal numbering requirements, if any, need a gapless counter — ADR).
