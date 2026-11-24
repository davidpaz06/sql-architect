# Quick Commands

Invocation: `/sql-architect <command> [arguments]`. The first token selects the command; the rest are its arguments in free text. Read the command's file and follow it. Without a known command, use the normal workflows in `SKILL.md`.

| Command | Arguments | File |
|---|---|---|
| `init` | `[project name]` | `init.md` |
| `generate` | `[blueprint] [notes]` | `generate.md` |
| `migrate` | `<concept>` | `migrate.md` |
| `devseed` | `[volume]` | `devseed.md` |
| `audit` | `[scope]` | `audit.md` |
| `check` | `[--drift]` | `check.md` |
| `adr` | `<decision>` | `adr.md` |
| `explain` | `<query or plan>` | `explain.md` |
| `erd` | `[schema]` | `erd.md` |

All commands that change files work inside an existing database repo, except `init` and `generate`, which create one. If a command needs a repo and none is found (no `database/` folder), say so and offer `init` or `generate`.
