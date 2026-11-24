# Blueprint: Finance and Accounting

Starting point for double-entry bookkeeping: chart of accounts, fiscal periods, an immutable journal and account balances. Single company, single currency per entry.

## Entities

| Table / view | Purpose |
|---|---|
| `currencies` | ISO 4217 catalog, natural code as PK (seeded) |
| `account_types` | asset, liability, equity, revenue, expense with their normal side (seeded) |
| `accounts` | Chart of accounts; only postable accounts take lines (generic chart seeded) |
| `fiscal_periods` | Non-overlapping periods (`daterange` + exclusion constraint), open or closed |
| `journal_entries` | Immutable entry headers; corrections are reversing entries |
| `journal_lines` | Immutable debit/credit lines |
| `account_balances` (view) | Balance per postable account, signed by its normal side |

## Functions

| Function | Purpose | Errors |
|---|---|---|
| `post_journal_entry(entry_on, memo, lines jsonb, currency_code)` | Posts a balanced entry into an open period | AP201 < 2 lines, AP202 unbalanced, AP203 no open period, AP204 account not postable/active, AP206 invalid line |
| `reverse_journal_entry(entry_id, entry_on, memo)` | Posts the mirror entry | AP203, AP205 already reversed, AP207 not found |

Both are `SECURITY DEFINER`; consumers have **no** `INSERT/UPDATE/DELETE` on the journal, so the balance rule can't be bypassed. The journal tables also carry append-only triggers.

## Flows

- `docs/flows/journal-entry-posting.md`

## Extensions

`pg_stat_statements` only (the exclusion constraint on a single range column uses GiST natively; `btree_gist` would only be needed to combine it with equality columns).

## Deliberate omissions

Multi-currency entries with exchange rates, parties (customers/vendors) and subledgers, invoices and payments, tax engine, cost centers/dimensions, budgets, period-close procedure (closing entries, retained earnings), multi-company consolidation.

## Extension ideas

- Subledgers: `parties` + `party_id` on lines for receivables/payables; invoices posting through `post_journal_entry()`.
- Dimensions: `cost_center_id`, `project_id` on lines.
- Defense in depth: a `DEFERRABLE INITIALLY DEFERRED` constraint trigger on `journal_lines` that re-checks balance per entry at commit, for writers that bypass the functions (the owner).
- Period balances table maintained at close, when `account_balances` over the full history gets slow (ADR first).
- Replace the seeded chart with the local plan (Spain PGC, Venezuela VEN-NIF).
