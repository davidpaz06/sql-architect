# Blueprints

Starter schemas for common MVPs. They are **starting points**: small (6–12 tables), following every convention of this skill, meant to be adapted with `/sql-architect generate <blueprint> <notes>`. Read a blueprint only when generating from it or when the user asks about it.

Each blueprint folder mirrors a generated repo:

```
<blueprint>/
├── README.md        purpose, entities, functions, omissions, extension ideas
├── database/        complete sources of truth (template files included, so the folder works on its own)
└── docs/            flows/ for key multi-write flows; adr/ when the blueprint denormalizes
```

Root files (build script, compose, `.env.example`, `contributing.md`) come from `templates/` at generation time; `bootstrap.sql` is always built, never stored.

## Available

| Blueprint | Folder | Tenancy | Highlights |
|---|---|---|---|
| Multi-tenant SaaS B2B | `saas-b2b/` | Shared schema + RLS | Tenants, global users + memberships, invitations, plans/subscriptions, audit log, tenant-safe composite FKs, definer functions for pre-tenant flows |
| E-commerce | `e-commerce/` | Single | Catalog with jsonb attributes (ADR), carts, checkout function with stock locking, order snapshots, idempotent payments |
| Inventory / ERP | `inventory-erp/` | Single | Purchasing, append-only stock ledger, trigger-maintained stock levels (ADR), transfers |
| Finance and accounting | `finance-accounting/` | Single | Double-entry journal, balanced posting and reversal functions, periods with exclusion constraint, immutable ledger |

All four were verified on `postgres:18`: bootstrap twice (idempotent), integrity checks, and behavioral tests of their functions, RLS and privileges. Re-run `scripts/verify-blueprints.sh` after editing any of them.

## Pending

Listed so the agent can say what's coming and offer `init` + modeling meanwhile:

| Blueprint | Notes for when it's built |
|---|---|
| Marketplace | Sellers as tenants, listings, orders split per seller, payouts, commissions |
| CRM | Accounts, contacts, deals with pipeline stages, activities |
| LMS | Courses, modules, lessons, enrollments, progress, quizzes |
| Project management | Workspaces, projects, tasks with ordering, comments, labels |
| HR | Employees, positions, contracts, time off, payroll periods |
| CMS / blogging | Posts with revisions, authors, categories/tags, media, publishing states |
| Bookings / appointments | Resources, availability, bookings with `tstzrange` + exclusion constraint (`btree_gist`) |
| Messaging / chat | Conversations, participants, messages (partitioned by time), read receipts |
| Logistics / delivery | Shipments, routes, stops, drivers, tracking events (PostGIS) |
| Social network / community | Profiles, follows, posts, reactions, feeds, moderation |

## Adapting a blueprint

- Keep the numeric prefixes with gaps of 10 so new tables slot in.
- Rename the `app_` role prefix to the project slug.
- Removing a table means removing its triggers, grants, seeds, checks and any flow references; run the build `check` and the bootstrap afterwards.
- Single-tenant blueprints become multi-tenant by adding `tenants`, `tenant_id` on every business table, RLS and `current_tenant_id()` — follow `saas-b2b` and `references/security.md`.
