# Blueprint: Multi-tenant SaaS B2B

Starting point for a B2B SaaS where organizations (tenants) subscribe to a plan and their members work on tenant-owned data. Shared schema + `tenant_id` + RLS.

## Entities

| Table | Purpose |
|---|---|
| `plans` | Catalog of subscription plans (identity key, seeded) |
| `tenants` | Customer organizations; each tenant sees only its own row |
| `users` | Global identities (a person can belong to several tenants); visible to a tenant only through memberships |
| `memberships` | User ↔ tenant with role (`owner`, `admin`, `member`) |
| `invitations` | Pending invitations, token stored hashed |
| `projects` | Example tenant-owned entity — replace with the product's real ones |
| `tasks` | Example child entity with a tenant-safe composite FK |
| `subscriptions` | Plan subscription per tenant, at most one live |
| `audit_logs` | Append-only audit trail per tenant |

## Functions (consumer API)

| Function | Purpose | Errors |
|---|---|---|
| `register_tenant(name, slug, email, full_name, password_hash, plan_code, trial_days)` | Sign-up: tenant + owner + trial | AP101 email registered, AP102 slug taken, AP104 plan invalid |
| `accept_invitation(token_hash, full_name, password_hash)` | Join a tenant from an invitation | AP103 invalid/used/expired |
| `find_user_for_login(email)` | Credentials lookup before tenant selection | — |
| `list_user_tenants(user_id)` | Tenants to choose from after sign-in | — |

All are `SECURITY DEFINER` because they act before a tenant context exists or across tenants. Everything else is plain SQL under RLS, after `set_config('app.tenant_id', …, true)`.

## Flows

- `docs/flows/new-tenant-registration.md`
- `docs/flows/invitation-acceptance.md`

## Extensions

`citext` (emails), `pg_stat_statements`. Both in the official `postgres:18` image.

## Deliberate omissions

Billing provider integration (invoices, payment methods, webhooks), SSO/OAuth identities, API keys, granular permissions beyond the three roles, feature flags, usage metering, notifications, file storage. Add them as the product requires; most are new tenant tables following the `projects` pattern.

## Extension ideas

- Fine-grained RBAC: `roles` + `permissions` + `role_permissions` per tenant.
- `api_keys (tenant_id, key_hash, scopes, last_used_at)` with a definer lookup function like `find_user_for_login`.
- Usage metering in a time-partitioned table (see `references/partitioning.md`).
- Sub-tenants (workspaces): add `workspace_id` and extend the policies, or switch the isolation column — record it in an ADR.
