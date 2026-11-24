# devseed

Generate (or regenerate) `database/seeds/dev.sql`: deterministic mock data for local development and tests.

Argument `[volume]`: `small` (default, ~10 rows per main entity), `medium` (~1 000), `large` (~100 000 on the biggest tables, for performance testing), or explicit numbers ("50 tenants, 2000 orders").

1. Read `references/seeds.md` and every model, to get the FK dependency order, checks, unique constraints and tenant tables.
2. Plan the data shape and confirm it briefly when the model is large: entities, counts, distributions (e.g. 80% of orders paid), how many tenants.
3. Write `dev.sql` from `templates/database/seeds/dev.sql`:
   - keep the header, the `APP_ENV` guard and the single transaction;
   - `\set` variables for counts at the top so the user can change volume;
   - deterministic ids `md5('<entity>-' || n)::uuid`, FKs computed from the same expressions;
   - values derived from `n` (modulo for categories, a fixed anchor date plus offsets for time) — no `now()`, no unseeded `random()`;
   - insert in FK order with `ON CONFLICT (id) DO NOTHING`;
   - respect every CHECK and UNIQUE (tenant-scoped uniques included); for functions that enforce invariants (ledgers, stock), insert through the function or produce data that satisfies the invariant;
   - each tenant gets its own data, so RLS can be exercised.
4. If `docker-compose.dev.yml` doesn't exist, create it from the template.
5. If a local database is reachable and the user confirms, load the seed twice (the second run must change nothing) and report row counts per table.
6. If the seed would need data a function generates (balances, totals), say so and generate it consistently rather than inserting impossible states.
