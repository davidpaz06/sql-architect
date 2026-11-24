# Integration Contract

The database is consumed by applications this skill doesn't write. To stay decoupled from any particular backend while fitting any of them, the repo publishes a contract: what a consumer needs to know, without naming the consumer.

Generate it as `docs/integration-contract.md` in the database repo at scaffolding, and keep it updated by the workflows that change its content.

## Contents

1. **Connection roles** — which login role each kind of consumer uses (API, workers, read-only), what it can do, and the environment variables holding the credentials. The owner role is for migrations only.
2. **Tenant context** (multi-tenant projects) — the exact statement to run at the start of every transaction:
   ```sql
   SELECT set_config('app.tenant_id', '<tenant uuid>', true);
   ```
   and the guarantee: without it, tenant tables return zero rows and inserts fail the policy check. Transaction-local, compatible with poolers in transaction mode.
3. **Callable functions** — signature, purpose, required role, and the flow doc that describes it.
4. **Error catalog** — every project SQLSTATE (`AP…`) with its meaning, plus the standard ones consumers should map (`23505` unique violation, `23503` FK violation, `23514` check violation, `23P01` exclusion violation, `42501` insufficient privilege, `40001` serialization failure → retry).
5. **Read models** — views and materialized views intended for consumers, with refresh behavior.
6. **Conventions consumers can rely on** — uuidv7 ids (generatable client-side), `timestamptz` in UTC, `numeric` money with a currency code, `updated_at` maintained by the database, soft delete semantics if enabled.
7. **Migration policy** — expand/contract windows: which changes are announced ahead and how long deprecated columns survive.

## Rules

- The contract describes the database side only. How a consumer implements transactions, maps errors or pools connections is the consumer's business.
- Changing anything in the contract is a breaking change for consumers unless it only adds: use expand/contract and announce the window in the contract itself.
