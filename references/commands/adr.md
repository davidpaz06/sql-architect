# adr

Create a numbered ADR for `<decision>`.

1. Read `references/normalization-and-adr.md` and the existing ADRs in `docs/adr/` (to number and to find ADRs this one supersedes or relates to).
2. Number: highest `ADR-NNN` + 1. File: `docs/adr/ADR-NNN-<decision-in-kebab-case>.md`.
3. Fill `templates/adr.md` from the conversation and the repo. Ask for what you can't infer — especially the **review trigger** (a measurable condition) and, for denormalizations, the **consistency mechanism** and its owner. Status `Proposed` unless the user says it's decided.
4. If it supersedes an ADR, update the old one's status to `Superseded by ADR-NNN`.
5. Add a pointer in the `COMMENT ON TABLE` of affected tables (via migration if the database is deployed) and link it from related flows.
6. Run the build `check` (file naming).
