# check

Verify the repo is consistent. Report results; don't fix anything without asking.

1. Run the build `check` (`node build.mjs check` / `python build.py check` / `./build.ps1 check`). Report each error with its fix.
2. If Docker or a throwaway PostgreSQL is available:
   - create a fresh database, run `bootstrap.sql` twice (idempotency);
   - run every migration twice against it (each must print `skip` — the baseline already contains them);
   - if `dev.sql` exists, run it twice with `APP_ENV=development`.
3. With `--drift` and a git base branch: run the drift test from `references/drift-check.md` (base bootstrap + new migrations vs current bootstrap, `pg_dump --schema-only` diff).
4. Clean up the throwaway containers/databases.
5. Report: passed checks, failures with the exact error and the file responsible, and whether CI has these checks wired (offer the workflow from `drift-check.md` if not).
