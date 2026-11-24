-- 020-categories.sql
-- Product categories as a simple tree (parent_id). Use ltree if deep path queries become common.
CREATE TABLE IF NOT EXISTS public.categories (
  id          uuid        NOT NULL DEFAULT uuidv7(),
  parent_id   uuid        NULL,
  name        text        NOT NULL,
  slug        text        NOT NULL,
  position    integer     NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_categories PRIMARY KEY (id),
  CONSTRAINT fk_categories_parent_id FOREIGN KEY (parent_id) REFERENCES public.categories (id) ON DELETE RESTRICT,
  CONSTRAINT uq_categories_slug UNIQUE (slug),
  CONSTRAINT ck_categories_not_own_parent CHECK (parent_id <> id)
);

CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON public.categories (parent_id);

COMMENT ON TABLE public.categories IS 'Category tree; position orders siblings';
