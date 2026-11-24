# Anti-Patterns

Check for these while modeling, migrating and reviewing — not only when asked. When you find one, name it, explain the consequence, and propose the fix; if it's outside the current task, flag it and offer to address it separately.

## Repo and process

| Anti-pattern | Why it hurts | Fix |
|---|---|---|
| Editing `bootstrap.sql` by hand | Overwritten by the next build; sources and bootstrap diverge | Edit sources, rebuild |
| Schema change without migration, or migration without updated sources | Environments drift; bootstrap creates a different schema than production | Rule of three in one commit; drift check in CI |
| Editing a merged migration | Databases that already ran it never get the change | New migration |
| Commented rollback / "down" migrations | Reverting one file in isolation breaks dependents | Forward-only fix migration |
| Running bootstrap against an existing production database | Can't alter existing tables; gives a false sense of being up to date | Migrations only |
| Secrets in SQL files or `.env` committed | Credential leak through git history | `\getenv`, `.env` ignored, rotate if leaked |

## Modeling

| Anti-pattern | Why it hurts | Fix |
|---|---|---|
| Singular or prefixed names (`user`, `tbl_user`, `user_name` in `users`) | Reserved words, noise, inconsistency | Plural tables, short columns |
| `timestamp` without time zone | Ambiguous instants across servers and DST | `timestamptz` |
| `float`/`money` for money | Rounding errors, locale-dependent type | `numeric(p,s)` + currency |
| Nullable by default, nullable booleans | Three-valued logic bugs | `NOT NULL` unless absence is meaningful |
| FKs without `ON DELETE`, or `CASCADE` everywhere | Accidental mass deletes or orphan surprises | Explicit action, `RESTRICT` by default |
| Missing FKs ("we validate in the app") | Orphans from every other writer, scripts and bugs | Declare FKs |
| Unnamed constraints | Generated names differ per environment; migrations can't target them | Name every constraint |
| Native ENUMs for evolving states | Values can't be removed/reordered | `text` + CHECK or catalog table |
| Repeating groups (`tag1`, `tag2`), CSV in a column | Breaks 1NF, unqueryable | Child table or array |
| EAV for ordinary attributes | Unqueryable, untyped, slow | Columns, or `jsonb` with an ADR |
| `jsonb` as a dumping ground for core fields | No constraints, poor stats, hidden schema | Promote filtered/joined fields to columns |
| Denormalization without an ADR | Nobody knows how the copy stays correct | ADR with consistency mechanism |
| Random UUIDv4 PKs on hot tables | Index page splits, bloat | `uuidv7()` |
| `serial` | Legacy semantics, permission quirks | `GENERATED ALWAYS AS IDENTITY` |

## Security

| Anti-pattern | Why it hurts | Fix |
|---|---|---|
| Tenant table without `ENABLE` + `FORCE` RLS, or policy without `WITH CHECK` | Cross-tenant reads or writes | Full RLS pattern (security.md) |
| Tenant set with session-level `SET` | Leaks between tenants through pooled connections | `set_config(…, true)` per transaction |
| `current_setting('app.tenant_id')::uuid` without `missing_ok` / `nullif` | Errors on unset or reset settings | `current_tenant_id()` |
| Application connecting as owner or superuser | RLS bypassed, DDL possible from the app | Dedicated login roles in groups |
| Granting to login roles directly | Privileges scattered, hard to revoke | Grant to NOLOGIN groups |
| Missing default privileges | New tables from migrations are inaccessible (or over-granted) | `ALTER DEFAULT PRIVILEGES FOR ROLE <owner>` |
| `SECURITY DEFINER` without fixed `search_path` | Privilege escalation via shadowed objects | `SET search_path`, qualified names, revoke from PUBLIC |
| Hashing passwords in SQL | Plaintext reaches the server and its logs | Hash in the application |

## Migrations and performance

| Anti-pattern | Why it hurts | Fix |
|---|---|---|
| DDL without `lock_timeout` | A waiting ALTER blocks all traffic behind it | `SET LOCAL lock_timeout` |
| `CREATE INDEX` (non-concurrent) on a live big table | Blocks writes for the whole build | `CONCURRENTLY` in a no-transaction migration |
| Adding FK/CHECK validated in one step on a big table | Long exclusive scan | `NOT VALID` + `VALIDATE` |
| Rename/retype in one step while consumers run | Breaks deployed code | Expand/contract |
| One-transaction backfill of millions of rows | Lock contention, bloat, replication lag | Batches |
| FK columns without index | Slow joins and parent deletes | Index (tenant-leading) |
| Speculative or duplicate indexes | Write amplification, memory | Evidence-based indexes; drop unused |
| Wrong composite order (range column first) | Index unusable for the equality filter | Equality columns first |
| Function on an indexed column in WHERE | Index ignored | Expression index or `citext` |
| Partitioning prematurely, or by a column queries don't filter on | Overhead with no pruning | Partition only with evidence, by the filter column |
| Business workflows in triggers | Hidden behavior, per-row cost, hard debugging | Explicit function or application code |
| `SELECT *` in views or functions exposed to consumers | Silent contract changes | Explicit column lists |
