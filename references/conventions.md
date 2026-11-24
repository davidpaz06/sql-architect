# Conventions

## Case

- **Files and directories**: kebab-case (`new-user-registration.md`, `020-users.sql`). Exceptions: the `MIG-` and `ADR-` prefixes.
- **SQL identifiers** — schemas, tables, columns, functions, parameters, variables, constraints, indexes, triggers, policies, roles: **snake_case**, lowercase, unquoted. Never create identifiers that need double quotes.

## Tables

- **Plural nouns**: `users`, `orders`, `order_items`. Plural is consistent and avoids most reserved words (`user`, `order`, `group`, `role`, `table`, `check`).
- If the plural still collides with a keyword or is ambiguous with a built-in concept, prefix it with `app_` (e.g. a naturally singular concept whose name is a keyword). Check against the PostgreSQL keyword list (Appendix C of the docs) when in doubt.
- Join tables: both entities in plural or the relationship name: `project_members`, `role_permissions`.
- Prefer one schema (`public`) for MVPs. Add schemas (`auth`, `billing`) when a bounded area deserves separate grants or ownership.

## Columns

- **Short, without the table name**: `users.first_name`, `tenants.address`, `orders.status` — never `users_first_name`, `tenant_address`, `order_status`. The table already gives the context.
- Primary key: `id`.
- Foreign keys: `<referenced table in singular>_id` (`tenant_id`, `customer_id`). When there are two FKs to the same table, qualify by role: `sender_id`, `recipient_id`; `parent_id` for self-references.
- Booleans: `is_` / `has_` / `can_` prefix (`is_active`, `has_mfa`).
- Timestamps: `_at` suffix (`created_at`, `paid_at`). Dates without time: `_on` (`born_on`, `due_on`).
- Quantities with a unit: put the unit in the name if ambiguous (`weight_g`, `duration_s`). Money: amount column + currency column (`amount`, `currency_code`).
- Avoid generic names that hide meaning (`data`, `info`, `value`, `type` alone): prefer `kind`, `category`, `payload` only when they're the real concept.

## Constraints and indexes

Pattern: `<prefix>_<table>_<detail>`.

| Object | Prefix | Example |
|---|---|---|
| Primary key | `pk_` | `pk_users` |
| Foreign key | `fk_` | `fk_orders_customer_id` |
| Unique | `uq_` | `uq_users_tenant_id_email` |
| Check | `ck_` | `ck_order_items_quantity_positive` |
| Exclusion | `ex_` | `ex_bookings_resource_id_period` |
| Index | `idx_` | `idx_orders_customer_id_created_at` |

Name every constraint explicitly; generated names differ between environments and break migrations that reference them. PostgreSQL truncates identifiers to 63 bytes: shorten the detail part, not the prefix.

## Other objects

| Object | Pattern | Example |
|---|---|---|
| Function | `verb_noun` | `create_order`, `post_journal_entry`, `current_tenant_id` |
| Trigger function | describes the action | `set_updated_at`, `prevent_mutation` |
| Trigger | `trg_<table>_<purpose>` | `trg_users_updated_at` |
| Policy | `<purpose>` (scoped to its table) | `tenant_isolation`, `owner_only` |
| View | plural noun, `v_` only if it would collide with a table | `active_subscriptions` |
| Materialized view | `mv_<name>` | `mv_daily_sales` |
| Role | `<project>_<consumer>` / `<project>_rw`, `<project>_ro` | `shop_api`, `shop_rw` |
| Function parameter | `p_` prefix | `p_tenant_id` |
| PL/pgSQL variable | `v_` prefix | `v_total` |

`p_`/`v_` prefixes prevent ambiguity with column names inside function bodies.

Roles are cluster-wide: prefix them with the project slug so several databases can share a server. Templates and blueprints use `app_`; replace it when scaffolding.

## Comments

Add `COMMENT ON TABLE` for every table and `COMMENT ON COLUMN` when the meaning, unit or allowed values are not obvious. Comments are visible in every client and in the generated ERD.
