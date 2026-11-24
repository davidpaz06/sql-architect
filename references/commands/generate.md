# generate

Create a complete database repo from a blueprint, adapted to the user's notes.

1. Read `references/blueprints/index.md`. If no blueprint was given, or it is marked *pending*, show the available ones and ask; offer `init` + modeling when none fits.
2. Read the blueprint's `README.md` and files, and the user's notes. List the adaptations you'll make: entities added/removed/renamed, tenancy, soft delete, extensions.
3. Ask the scaffolding questions not already answered by the notes.
4. Show the final tree (repo structure + every model file) and wait for confirmation.
5. Do `init` steps 4–6, then copy the blueprint's `database/` and `docs/` over the skeleton and apply the adaptations. Keep every convention: headers, numeric prefixes, naming, RLS on tenant tables, grants for new functions, checks for new seeds.
6. If the user adapted a table that a blueprint flow describes, update that flow.
7. Generate `docs/integration-contract.md` with the functions and error codes the blueprint defines.
8. Build, `check`, and verify with Docker (bootstrap twice). If the dev seed was requested, run `devseed` and load it.
9. Summarize what was generated and the deliberate omissions listed in the blueprint's README that the user may want next.

The project starts without migrations: until the first shared deployment, the user may model directly in the sources (see the "never-deployed repos" note in `references/migrations.md`).
