# Stock transfer

## Purpose

Move a quantity of an item from one warehouse to another, keeping both levels and the ledger consistent.

## Actors and roles

Warehouse staff via the consumer as `app_api` (`app_rw`). The function is `SECURITY DEFINER` because it locks `stock_levels`, which consumers can only read.

## Steps

1. `transfer_stock(item, from, to, quantity, note)` validates quantity > 0 and different warehouses.
2. Locks the source `stock_levels` row (`FOR UPDATE`) and checks availability.
3. Inserts a `transfer_out` (negative) and a `transfer_in` (positive) movement sharing a new uuidv7 as `reference_id`.
4. The trigger updates both levels.
5. Returns the transfer reference.

## Invariants

- The two movements of a transfer always exist together (same transaction) and sum to zero.
- No level goes below zero (CHECK on `stock_levels`, also pre-checked for a friendly error).

## Implementation

`public.transfer_stock(p_item_id uuid, p_from_warehouse_id uuid, p_to_warehouse_id uuid, p_quantity numeric, p_note text DEFAULT NULL) RETURNS uuid`

## Errors

| SQLSTATE | Condition | Meaning for the consumer |
|---|---|---|
| AP302 | Insufficient stock in the source | Show available quantity |
| AP303 | Quantity ≤ 0 | Client error |
| AP304 | Same source and destination | Client error |
| 23514 | `ck_stock_levels_quantity_non_negative` (race with a concurrent issue) | Same as AP302 |

## Concurrency

The source level row lock serializes competing transfers and issues for the same item and warehouse. In-transit stock (goods on a truck) is not modeled: add a transit warehouse if needed.
