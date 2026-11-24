-- schemas.sql
-- Schemas owned by the owner role; then the rest of the bootstrap runs as that role.
ALTER SCHEMA public OWNER TO app_owner;
-- CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION app_owner;

-- Every object created from here on (functions, tables, triggers, seeds) belongs to app_owner.
SET LOCAL ROLE app_owner;
