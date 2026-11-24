# New tenant registration

## Purpose

A visitor signs up: a new organization is created with them as its owner, on a trial of the chosen plan.

## Actors and roles

Unauthenticated visitor, through the consumer connected as `app_api` (group `app_rw`). No tenant context exists yet, so the operation runs in `register_tenant()` (`SECURITY DEFINER`).

## Steps

1. Consumer validates input format and hashes the password (argon2id/bcrypt). The database never sees the plaintext.
2. `register_tenant()` checks the email is not registered and the slug is free, and resolves the plan by code.
3. Inserts `tenants`, `users`, `memberships` (role `owner`), `subscriptions` (`trialing`, period = now … now + trial days) and an `audit_logs` row `tenant.registered`.
4. Returns `(tenant_id, user_id)`; the consumer starts a session for that user and tenant.

## Invariants

- Every tenant has exactly one owner membership at creation and one live subscription.
- Emails are unique case-insensitively (`citext`); slugs are unique and kebab-case.

## Implementation

`public.register_tenant(p_tenant_name text, p_slug text, p_email text, p_full_name text, p_password_hash text, p_plan_code text DEFAULT 'free', p_trial_days integer DEFAULT 14) RETURNS TABLE (tenant_id uuid, user_id uuid)`

## Errors

| SQLSTATE | Condition | Meaning for the consumer |
|---|---|---|
| AP101 | Email already registered | Ask the user to sign in |
| AP102 | Slug taken | Ask for another slug |
| AP104 | Plan code unknown or inactive | Client error |
| 23505 | Race on email or slug between check and insert | Same as AP101/AP102; retry is safe |

## Concurrency

The pre-checks give friendly errors; the unique constraints are the real guarantee under concurrency. The whole function runs in the caller's transaction.
