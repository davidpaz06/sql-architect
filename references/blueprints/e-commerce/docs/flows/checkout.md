# Checkout

## Purpose

Convert a customer's open cart into an order, guaranteeing stock is available and reserving it in the same transaction.

## Actors and roles

Customer (registered or guest, already identified as a `customers` row) via the consumer as `app_api` (`app_rw`).

## Steps

1. Consumer ensures the customer exists (creates a guest customer if needed) and the address belongs to them, and computes shipping.
2. `place_order()` locks the cart and checks it is `open` and not empty.
3. Locks every product in the cart **ordered by id** (prevents deadlocks between concurrent checkouts) and validates: active, same currency as the cart, enough stock.
4. Inserts the order with subtotal, shipping, total and the address snapshot (`ship_to`).
5. Inserts order lines copying sku, name and current price.
6. Decrements `products.stock_quantity`; marks the cart `converted`.
7. Returns `(order_id, order_number)`. The consumer starts the payment with the provider.

Payment confirmation (webhook) is a separate, plain update: insert/update `payments` by `(provider, provider_ref)` and set the order `paid`.

## Invariants

- `stock_quantity` never goes below zero (CHECK constraint backs the function's validation).
- `orders.total = subtotal + shipping_total` (CHECK).
- A cart produces at most one order (`uq_orders_cart_id`).
- Order lines never change after creation (append-only trigger + revoked privileges).

## Implementation

`public.place_order(p_cart_id uuid, p_customer_id uuid, p_address_id uuid, p_shipping_total numeric DEFAULT 0) RETURNS TABLE (order_id uuid, order_number bigint)`

## Errors

| SQLSTATE | Condition | Meaning for the consumer |
|---|---|---|
| AP101 | Cart empty | Back to cart |
| AP102 | Insufficient stock (message names the SKU) | Show availability, let the user adjust |
| AP103 | Cart not open (already converted or abandoned) | Idempotent retry: look up the order by cart |
| AP104 | Product priced in another currency | Configuration error |
| AP105 | Address doesn't belong to the customer | Client error |
| AP106 | Product deactivated since added to cart | Remove item, retry |

## Concurrency

Row locks on the cart and products (`FOR UPDATE`) serialize competing checkouts on the same products only. Unpaid orders keep their stock: a scheduled job cancels `pending_payment` orders after a timeout and restores stock (add it as a function when payment flows are defined).
