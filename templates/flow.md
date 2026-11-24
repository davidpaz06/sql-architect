# <Flow name>

## Purpose

What the business operation achieves, in one or two sentences.

## Actors and roles

Who triggers it and which database role executes it (e.g. app_api through app_rw).

## Steps

1. Validation performed and where (consumer or database).
2. Each write, in order, with the table it touches.

## Invariants

Rules that must hold when the transaction commits (e.g. "debits equal credits per journal entry").

## Implementation

Function or statements that implement the flow, with signature:
`public.<verb_noun>(p_arg type, …) RETURNS …`

## Errors

| SQLSTATE | Condition | Meaning for the consumer |
|---|---|---|
| AP1xx | … | … |

## Concurrency

Locks taken, isolation level required, idempotency key if the operation can be retried.
