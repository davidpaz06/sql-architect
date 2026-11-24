# Purchase order receipt

## Purpose

Register the arrival of a purchase order's goods in its destination warehouse, increasing stock.

## Actors and roles

Warehouse staff via the consumer as `app_api` (`app_rw`).

## Steps

1. Consumer creates the PO (`draft`) and its lines with plain inserts, then sets it to `ordered` when sent to the supplier.
2. On arrival, the consumer calls `receive_purchase_order(po_id)`.
3. The function locks the PO, checks it is `ordered`, and inserts one `receipt` movement per line into the PO's warehouse, referenced as `('purchase_order', po_id)`.
4. The `trg_stock_movements_apply` trigger adds each movement to `stock_levels`.
5. PO status becomes `received` with `received_at`.

## Invariants

- A PO is received at most once (status check under row lock).
- `status = 'received'` ⇔ `received_at IS NOT NULL` (CHECK).
- Every stock change is traceable to its document through `reference_type` / `reference_id`.

## Implementation

`public.receive_purchase_order(p_purchase_order_id uuid) RETURNS integer` (number of lines received). `SECURITY INVOKER`.

## Errors

| SQLSTATE | Condition | Meaning for the consumer |
|---|---|---|
| AP301 | PO not in status `ordered` (draft, already received, cancelled) | Refresh and show current status |
| AP305 | PO has no lines | Client error |

## Concurrency

`FOR UPDATE` on the PO row: two simultaneous receipts serialize and the second gets AP301.
