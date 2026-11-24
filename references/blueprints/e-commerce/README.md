# Blueprint: E-commerce

Starting point for a single-store online shop: catalog, customers, carts, checkout with stock reservation, orders and payments. Single-tenant (for a multi-store platform, combine with the SaaS B2B blueprint's tenancy pattern).

## Entities

| Table | Purpose |
|---|---|
| `currencies` | ISO 4217 catalog, natural code as PK (seeded) |
| `categories` | Category tree (`parent_id`) |
| `products` | Catalog with price, stock and category-specific `attributes` (jsonb, ADR-001) |
| `customers` | Registered and guest customers |
| `addresses` | Customer address book |
| `carts`, `cart_items` | Shopping carts; prices are read at checkout |
| `orders` | Placed orders with amount and address snapshots, human-facing `number` |
| `order_items` | Immutable lines with product snapshots |
| `payments` | Payment attempts, idempotent per `(provider, provider_ref)` |

## Functions

| Function | Purpose | Errors |
|---|---|---|
| `place_order(cart_id, customer_id, address_id, shipping_total)` | Checkout: order + lines + stock decrement + cart converted | AP101 empty cart, AP102 insufficient stock, AP103 cart not open, AP104 currency mismatch, AP105 address not the customer's, AP106 product inactive |

`SECURITY INVOKER`: consumers already have table privileges; the function exists to keep the checkout invariants (stock never negative, snapshot consistency, one order per cart) in one place with the right locks.

## Flows

- `docs/flows/checkout.md`

## Extensions

`citext` (emails), `pg_trgm` (fuzzy product search on `name`), `pg_stat_statements`. All in the official `postgres:18` image.

## Deliberate omissions

Product variants (size/color as separate SKUs), price lists and discounts/coupons, taxes, shipping methods and rates, inventory per warehouse (see the inventory-erp blueprint), returns/refunds workflow, reviews, wishlists, multi-currency pricing per product.

## Extension ideas

- Variants: `product_variants (product_id, sku, attributes, price, stock_quantity)` and move stock/price there.
- Promotions: `coupons` + `order_discounts` applied inside `place_order()`.
- Stock reservations with expiry instead of immediate decrement, for long payment flows.
- Search: `tsvector` generated column + GIN for ranked full-text in addition to trigrams.
