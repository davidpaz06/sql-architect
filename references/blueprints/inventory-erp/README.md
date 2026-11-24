# Blueprint: Inventory / ERP

Starting point for multi-warehouse inventory with purchasing: items, suppliers, purchase orders, an immutable stock ledger and current stock levels. Single-tenant.

## Entities

| Table | Purpose |
|---|---|
| `units` | Units of measure (identity catalog, seeded) |
| `warehouses` | Stock locations |
| `suppliers` | Suppliers |
| `items` | Inventory items with standard cost and reorder point |
| `purchase_orders`, `purchase_order_lines` | Purchasing, received into one warehouse |
| `stock_movements` | **Append-only ledger**: every stock change is a signed movement (source of truth) |
| `stock_levels` | Current quantity per item and warehouse, derived from the ledger by trigger (ADR-001) |

## Functions

| Function | Purpose | Errors |
|---|---|---|
| `receive_purchase_order(purchase_order_id)` | Receipt movements for every line, PO → `received` | AP301 not in status ordered, AP305 no lines |
| `transfer_stock(item_id, from, to, quantity, note)` | Pair of transfer movements with a shared reference | AP302 insufficient stock, AP303 quantity ≤ 0, AP304 same warehouse |
| `apply_stock_movement()` | Trigger function keeping `stock_levels` in sync | 23514 on `ck_stock_levels_quantity_non_negative` = insufficient stock |

Issues (sales, consumption) and adjustments are plain inserts into `stock_movements` with the right sign; the trigger updates the level and the CHECK rejects going below zero.

## Flows

- `docs/flows/purchase-order-receipt.md`
- `docs/flows/stock-transfer.md`

## Extensions

`pg_stat_statements` only.

## Deliberate omissions

Lots/serial numbers and expiry dates, bin locations inside warehouses, partial receipts, inventory valuation (FIFO/weighted average cost), sales orders and reservations, unit conversions, multi-company, accounting integration (see the finance-accounting blueprint).

## Extension ideas

- Partial receipts: `received_quantity` per PO line and `receive_purchase_order_lines(po_id, jsonb)`.
- Valuation: `unit_cost` on movements + a cost layer table for FIFO, or a running weighted average on `stock_levels`.
- Reservations: `reserved_quantity` on `stock_levels` and a `stock_reservations` table, so available = quantity − reserved.
- Very large ledgers: partition `stock_movements` by month on `occurred_at` (see `references/partitioning.md`).
