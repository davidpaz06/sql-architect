#!/usr/bin/env python3
# build.py
# Assembles bootstrap.sql from the sources of truth in database/ and validates the repo.
#
# Usage:
#   python build.py build              regenerate bootstrap.sql
#   python build.py check              exit 1 if bootstrap.sql is stale or the repo breaks conventions
#   python build.py migrate            apply pending migrations with psql ($DATABASE_URL)
#   python build.py migrate --docker   apply pending migrations inside the compose service "db"
#
# Standard library only. Output is byte-identical to build.mjs and build.ps1.

import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DB = ROOT / "database"
OUT = ROOT / "bootstrap.sql"

MIGRATION_RE = re.compile(r"^MIG-(\d{3,})-[a-z0-9]+(?:-[a-z0-9]+)*-(\d{12})\.sql$")
ADR_RE = re.compile(r"^ADR-\d{3,}-[a-z0-9]+(?:-[a-z0-9]+)*\.md$")
KEBAB_FILE_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*\.(sql|md)$")
KEBAB_DIR_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8").replace("\r\n", "\n")


def walk(d: Path):
    return [p for p in d.rglob("*") if p.is_file()] if d.exists() else []


def walk_dirs(d: Path):
    return [p for p in d.rglob("*") if p.is_dir()] if d.exists() else []


def sql_files(d: Path, exclude=()):
    # Ordered by file name first (numeric prefix is global across schema subfolders), then path.
    files = [p for p in walk(d) if p.suffix == ".sql" and p.name not in exclude]
    return sorted(files, key=lambda p: f"{p.name}\0{rel(p)}")


def migrations():
    names = [p.name for p in sql_files(DB / "migrations") if MIGRATION_RE.match(p.name)]
    return sorted(names, key=lambda n: int(MIGRATION_RE.match(n).group(1)))


def generate() -> str:
    sections = [
        ("1. Extensions", [DB / "extensions.sql"]),
        ("2. Roles (run as superuser)", [DB / "security" / "roles.sql"]),
        ("3. Schemas (switches to the owner role at the end)", [DB / "schemas.sql"]),
        ("4. Functions", sql_files(DB / "functions")),
        ("5. Models", sql_files(DB / "models")),
        ("6. Triggers", sql_files(DB / "triggers")),
        ("7. Grants", sql_files(DB / "security", ("roles.sql",))),
        ("8. Reference seeds", sql_files(DB / "seeds", ("dev.sql",))),
    ]
    lines = [
        "-- bootstrap.sql",
        "-- GENERATED FILE. Do not edit by hand: change the sources in database/ and run the build.",
        "-- Creates a database from scratch in one transaction. Only for new environments;",
        "-- existing databases receive migrations (database/migrations/).",
        "",
        "\\set ON_ERROR_STOP on",
        "",
        "BEGIN;",
        "SET LOCAL check_function_bodies = off;",
        "SET LOCAL client_min_messages = 'warning';",
    ]
    for title, files in sections:
        lines += ["", f"-- {title}"]
        present = [f for f in files if f.exists()]
        if not present:
            lines.append("-- (none)")
        lines += [f"\\ir {rel(f)}" for f in present]

    lines += ["", "RESET ROLE;", "", "-- 9. Migration baseline: this schema already contains every migration below"]
    ids = [n[:-4] for n in migrations()]
    if not ids:
        lines.append("-- (no migrations yet)")
    else:
        lines.append("INSERT INTO public.schema_migrations (id, applied_by) VALUES")
        lines += [f"  ('{i}', 'bootstrap'){',' if k < len(ids) - 1 else ''}" for k, i in enumerate(ids)]
        lines.append("ON CONFLICT (id) DO NOTHING;")

    lines += [
        "",
        "-- 10. Integrity checks (any failure rolls back the whole bootstrap)",
        "DO $$",
        "DECLARE r record;",
        "BEGIN",
        "  FOR r IN",
        "    SELECT c.oid::regclass AS tbl, c.relrowsecurity AS rls, c.relforcerowsecurity AS forced,",
        "           EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = c.oid) AS has_policy",
        "    FROM pg_class c",
        "    JOIN pg_namespace n ON n.oid = c.relnamespace",
        "    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = 'tenant_id' AND NOT a.attisdropped",
        "    WHERE c.relkind IN ('r', 'p') AND NOT c.relispartition",
        "      AND n.nspname NOT IN ('pg_catalog', 'information_schema')",
        "  LOOP",
        "    IF NOT (r.rls AND r.forced AND r.has_policy) THEN",
        "      RAISE EXCEPTION 'integrity: % has tenant_id but RLS is not enabled, forced and covered by a policy', r.tbl;",
        "    END IF;",
        "  END LOOP;",
        "END $$;",
    ]
    if (DB / "checks.sql").exists():
        lines.append(f"\\ir {rel(DB / 'checks.sql')}")
    lines += ["", "COMMIT;", ""]
    return "\n".join(lines)


def check() -> None:
    errors = []
    if not OUT.exists():
        errors.append("bootstrap.sql is missing: run the build")
    elif read(OUT) != generate():
        errors.append("bootstrap.sql is stale: run the build")

    if not any(p.name.endswith("schema-migrations.sql") for p in walk(DB / "models")):
        errors.append("database/models has no *-schema-migrations.sql model")

    numbers = []
    for p in walk(DB / "migrations"):
        if p.name == ".gitkeep":
            continue
        m = MIGRATION_RE.match(p.name)
        if not m:
            errors.append(f"{rel(p)}: migration name must match MIG-NNN-<kebab-concept>-<YYYYMMDDHHmm>.sql")
            continue
        numbers.append(int(m.group(1)))
    for i, n in enumerate(sorted(numbers)):
        if n != i + 1:
            errors.append(f"migrations: numbering must be unique and contiguous from 001 (found {n:03d} at position {i + 1})")

    for base in (DB, ROOT / "docs"):
        for d in walk_dirs(base):
            if not KEBAB_DIR_RE.match(d.name):
                errors.append(f"{rel(d)}: directory names must be kebab-case")
        for p in walk(base):
            if p.name == ".gitkeep":
                continue
            if not (KEBAB_FILE_RE.match(p.name) or MIGRATION_RE.match(p.name) or ADR_RE.match(p.name)):
                errors.append(f"{rel(p)}: file names must be kebab-case (.sql or .md)")

    for p in [p for p in walk(DB) if p.suffix == ".sql"]:
        lines = read(p).split("\n") + ["", ""]
        if lines[0].strip() != f"-- {p.name}":
            errors.append(f'{rel(p)}: line 1 must be "-- {p.name}"')
        if not re.match(r"^--\s+\S", lines[1]):
            errors.append(f'{rel(p)}: line 2 must be a short "-- <purpose>" comment')

    if errors:
        print(f"check failed ({len(errors)}):\n  - " + "\n  - ".join(errors), file=sys.stderr)
        sys.exit(1)
    print("check passed")


def migrate(use_docker: bool) -> None:
    files = migrations()
    url = os.environ.get("DATABASE_URL")
    if not use_docker and not url:
        sys.exit("DATABASE_URL is not set (or use: migrate --docker)")
    for name in files:
        sql = read(DB / "migrations" / name)
        if use_docker:
            cmd = ["docker", "compose", "exec", "-T", "db", "sh", "-c",
                   'psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"']
        else:
            cmd = ["psql", "-X", "-q", "-v", "ON_ERROR_STOP=1", url]
        res = subprocess.run(cmd, input=sql, text=True)
        if res.returncode != 0:
            print(f"migration failed: {name}", file=sys.stderr)
            sys.exit(res.returncode)
        print(f"ok  {name}")
    print(f"{len(files)} migration(s) checked; already-applied ones were skipped by their guard")


if __name__ == "__main__":
    args = sys.argv[1:]
    cmd = args[0] if args else "build"
    if cmd == "build":
        OUT.write_bytes(generate().encode("utf-8"))
        print(f"wrote {rel(OUT)}")
    elif cmd == "check":
        check()
    elif cmd == "migrate":
        migrate(len(args) > 1 and args[1] == "--docker")
    else:
        sys.exit("usage: python build.py [build|check|migrate [--docker]]")
