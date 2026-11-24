# erd

Generate a Mermaid entity-relationship diagram of the current schema at `docs/erd.md` (one diagram per schema when there are several, or only `[schema]` if given).

1. Source: the model files (preferred, always current with the repo). If a database built from the current bootstrap is reachable, the catalog may be used instead — it resolves inherited details exactly.
2. Content per table: name, PK, FKs, and the columns that matter for understanding (skip `created_at`/`updated_at` to reduce noise; mention it in a note). Mark `PK`, `FK`, `UK`.
3. Relationships from FKs with cardinality: `||--o{` (one to many, optional child), `||--|{` (mandatory child), `|o--o{` for nullable FKs, `||--||` for 1:1 (FK with a unique constraint). Label with the FK column.
4. Write:

   ````markdown
   # ERD — <schema>
   Generated from database/models on YYYY-MM-DD. Audit columns omitted.

   ```mermaid
   erDiagram
     tenants ||--o{ users : tenant_id
     tenants {
       uuid id PK
       text name
     }
     users {
       uuid id PK
       uuid tenant_id FK
       citext email UK
     }
   ```
   ````
5. Large schemas (> ~25 tables): one diagram per area/schema plus a small overview diagram with only table names and relationships.
6. The ERD is derived: regenerate it after schema changes (mention it in the migration summary). It never replaces the models as source of truth.
