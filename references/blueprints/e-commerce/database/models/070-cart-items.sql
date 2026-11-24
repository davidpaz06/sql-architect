-- 070-cart-items.sql
-- Products in a cart. Prices are read at checkout, not stored here.
CREATE TABLE IF NOT EXISTS public.cart_items (
  id          uuid        NOT NULL DEFAULT uuidv7(),
  cart_id     uuid        NOT NULL,
  product_id  uuid        NOT NULL,
  quantity    integer     NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_cart_items PRIMARY KEY (id),
  CONSTRAINT fk_cart_items_cart_id FOREIGN KEY (cart_id) REFERENCES public.carts (id) ON DELETE CASCADE,
  CONSTRAINT fk_cart_items_product_id FOREIGN KEY (product_id) REFERENCES public.products (id) ON DELETE RESTRICT,
  CONSTRAINT uq_cart_items_cart_id_product_id UNIQUE (cart_id, product_id),
  CONSTRAINT ck_cart_items_quantity_positive CHECK (quantity > 0)
);

CREATE INDEX IF NOT EXISTS idx_cart_items_product_id ON public.cart_items (product_id);

COMMENT ON TABLE public.cart_items IS 'Cart lines; one row per product';
