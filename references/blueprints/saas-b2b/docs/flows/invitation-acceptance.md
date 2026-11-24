# Invitation acceptance

## Purpose

A person invited by a tenant admin joins the tenant, creating their account if they don't have one.

## Actors and roles

- Inviting: an `owner`/`admin` of the tenant, via the consumer as `app_api` under the tenant context: plain `INSERT INTO invitations` (RLS scopes it). The consumer generates a random token, emails it, and stores only its hash.
- Accepting: the invitee, possibly without an account, via `accept_invitation()` (`SECURITY DEFINER`, no tenant context yet).

## Steps

1. Consumer hashes the token received in the link (and the password, if the invitee is new).
2. `accept_invitation()` locks the invitation row (`FOR UPDATE`) and checks it is pending and not expired.
3. Finds the user by the invitation email or creates it.
4. Inserts the membership with the invited role (no-op if already a member), marks the invitation accepted, writes `audit_logs` `member.joined`.
5. Returns `(tenant_id, user_id)`.

## Invariants

- An invitation is used at most once.
- At most one pending invitation per email and tenant (partial unique index).
- The role granted is the one stored in the invitation, never a value from the request.

## Implementation

`public.accept_invitation(p_token_hash text, p_full_name text, p_password_hash text) RETURNS TABLE (tenant_id uuid, user_id uuid)`

## Errors

| SQLSTATE | Condition | Meaning for the consumer |
|---|---|---|
| AP103 | Token unknown, already used or expired | Show "invitation no longer valid" |

## Concurrency

`FOR UPDATE` on the invitation serializes double clicks: the second call sees `accepted_at` set and gets AP103.
