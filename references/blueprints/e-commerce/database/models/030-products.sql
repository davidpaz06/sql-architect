-- 030-products.sql
-- Sellable products with price, stock and category-specific attributes (jsonb, see ADR-001).
CREATE TABLE IF NOT EXISTS public.products (
  id              uuid          NOT NULL DEFAULT uuidv7(),
  category_id     uuid          NULL,
  sku             text          NOT NULL,
  name            text          NOT NULL,
  slug            text          NOT NULL,
  description     text          NULL,
  price           numeric(12,2) NOT NULL,
  currency_code   text          NOT NULL,
  stock_quantity  integer       NOT NULL DEFAULT 0,
  attributes      jsonb         NOT NULL DEFAULT '{}',
  is_active       boolean       NOT NULL DEFAULT true,
  created_at      timestamptz   NOT NULL DEFAULT now(),
  updated_at      timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT pk_products PRIMARY KEY (id),
  CONSTRAINT fk_products_category_id FOREIGN KEY (category_id) REFERENCES public.categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_products_currency_code FOREIGN KEY (currency_code) REFERENCES public.currencies (code) ON DELETE RESTRICT,
  CONSTRAINT uq_products_sku UNIQUE (sku),
  CONSTRAINT uq_products_slug UNIQUE (slug),
  CONSTRAINT ck_products_price_non_negative CHECK (price >= 0),
  CONSTRAINT ck_products_stock_quantity_non_negative CHECK (stock_quantity >= 0),
  CONSTRAINT ck_products_attributes_object CHECK (jsonb_typeof(attributes) = 'object')
);

CREATE INDEX IF NOT EXISTS idx_products_category_id ON public.products (category_id) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_products_currency_code ON public.products (currency_code);
CREATE INDEX IF NOT EXISTS idx_products_name_trgm ON public.products USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_products_attributes ON public.products USING gin (attributes jsonb_path_ops);

COMMENT ON TABLE public.products IS 'Catalog products. attributes: category-specific fields, see docs/adr/ADR-001';
COMMENT ON COLUMN public.products.stock_quantity IS 'Units available; decremented atomically by place_order()';
