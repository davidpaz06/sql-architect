# ADR-001: Category-specific product attributes in jsonb

- Status: Accepted
- Date: 2026-11-25

## Context

Products in different categories have different attributes (size and color for apparel, capacity for mugs, ISBN for books). Modeling every attribute as a column produces wide, mostly-null tables and a migration per new category. A fully normalized attribute model (EAV) makes listing and filtering products expensive and validation weak.

## Decision

Store category-specific attributes in `products.attributes jsonb` (a JSON object), with a GIN `jsonb_path_ops` index for containment filters (`attributes @> '{"color": "red"}'`). Attributes that become central to the business (used in joins, pricing, stock or most filters) are promoted to real columns through expand/contract.

## Alternatives considered

- Columns per attribute: strong typing, but constant migrations and sparse tables.
- EAV (`product_attributes (product_id, name, value)`): flexible, but queries need one join per attribute and values lose their types.
- Table per category (class table inheritance): clean per category, heavy for an MVP with many small categories.

## Consequences

Flexible catalog without migrations for new attributes. Trade-offs: no per-attribute types or NOT NULL in the database (only `jsonb_typeof(attributes) = 'object'` is enforced); typos in keys are possible; statistics on individual keys are weaker.

## Consistency mechanism

The consumer validates attributes per category before writing (schema per category in the application). The database enforces only that `attributes` is an object.

## Review trigger

Promote an attribute to a column when it is used in more than a few frequent filters/sorts, or when a category needs per-attribute validation in the database (e.g. a `CHECK` on a size list). Reconsider the whole approach if product variants are introduced.

## Related

`public.products`, `idx_products_attributes`.
