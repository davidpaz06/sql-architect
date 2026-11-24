#!/usr/bin/env node
// build.mjs
// Assembles bootstrap.sql from the sources of truth in database/ and validates the repo.
//
// Usage:
//   node build.mjs build              regenerate bootstrap.sql
//   node build.mjs check              exit 1 if bootstrap.sql is stale or the repo breaks conventions
//   node build.mjs migrate            apply pending migrations with psql ($DATABASE_URL)
//   node build.mjs migrate --docker   apply pending migrations inside the compose service "db"
//
// No dependencies. Output is byte-identical to build.py and build.ps1.

import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { join, relative, sep, basename, dirname } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = dirname(fileURLToPath(import.meta.url));
const DB = join(ROOT, 'database');
const OUT = join(ROOT, 'bootstrap.sql');

const MIGRATION_RE = /^MIG-(\d{3,})-[a-z0-9]+(?:-[a-z0-9]+)*-(\d{12})\.sql$/;
const ADR_RE = /^ADR-\d{3,}-[a-z0-9]+(?:-[a-z0-9]+)*\.md$/;
const KEBAB_FILE_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*\.(sql|md)$/;
const KEBAB_DIR_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

const rel = (p) => relative(ROOT, p).split(sep).join('/');
const read = (p) => readFileSync(p, 'utf8').replace(/\r\n/g, '\n');
const ordinal = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

function walk(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(join(dir, e.name)) : [join(dir, e.name)]);
}

function walkDirs(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true })
    .filter((e) => e.isDirectory())
    .flatMap((e) => [join(dir, e.name), ...walkDirs(join(dir, e.name))]);
}

// Files are ordered by file name first (the numeric prefix is global across schema
// subfolders, so cross-schema dependencies resolve), then by relative path.
const sortKey = (p) => `${basename(p)}\u0000${rel(p)}`;
const sqlFiles = (dir, exclude = []) =>
  walk(dir)
    .filter((f) => f.endsWith('.sql') && !exclude.includes(basename(f)))
    .sort((a, b) => ordinal(sortKey(a), sortKey(b)));

function migrations() {
  return sqlFiles(join(DB, 'migrations'))
    .map((f) => basename(f))
    .filter((n) => MIGRATION_RE.test(n))
    .sort((a, b) => Number(a.match(MIGRATION_RE)[1]) - Number(b.match(MIGRATION_RE)[1]));
}

function generate() {
  const sections = [
    ['1. Extensions', [join(DB, 'extensions.sql')]],
    ['2. Roles (run as superuser)', [join(DB, 'security', 'roles.sql')]],
    ['3. Schemas (switches to the owner role at the end)', [join(DB, 'schemas.sql')]],
    ['4. Functions', sqlFiles(join(DB, 'functions'))],
    ['5. Models', sqlFiles(join(DB, 'models'))],
    ['6. Triggers', sqlFiles(join(DB, 'triggers'))],
    ['7. Grants', sqlFiles(join(DB, 'security'), ['roles.sql'])],
    ['8. Reference seeds', sqlFiles(join(DB, 'seeds'), ['dev.sql'])],
  ];

  const lines = [
    '-- bootstrap.sql',
    '-- GENERATED FILE. Do not edit by hand: change the sources in database/ and run the build.',
    '-- Creates a database from scratch in one transaction. Only for new environments;',
    '-- existing databases receive migrations (database/migrations/).',
    '',
    '\\set ON_ERROR_STOP on',
    '',
    'BEGIN;',
    'SET LOCAL check_function_bodies = off;',
    "SET LOCAL client_min_messages = 'warning';",
  ];

  for (const [title, files] of sections) {
    lines.push('', `-- ${title}`);
    const present = files.filter((f) => existsSync(f));
    if (present.length === 0) lines.push('-- (none)');
    for (const f of present) lines.push(`\\ir ${rel(f)}`);
  }

  lines.push('', 'RESET ROLE;', '', '-- 9. Migration baseline: this schema already contains every migration below');
  const ids = migrations().map((n) => n.replace(/\.sql$/, ''));
  if (ids.length === 0) {
    lines.push('-- (no migrations yet)');
  } else {
    lines.push('INSERT INTO public.schema_migrations (id, applied_by) VALUES');
    ids.forEach((id, i) => lines.push(`  ('${id}', 'bootstrap')${i < ids.length - 1 ? ',' : ''}`));
    lines.push('ON CONFLICT (id) DO NOTHING;');
  }

  lines.push(
    '',
    '-- 10. Integrity checks (any failure rolls back the whole bootstrap)',
    'DO $$',
    'DECLARE r record;',
    'BEGIN',
    '  FOR r IN',
    '    SELECT c.oid::regclass AS tbl, c.relrowsecurity AS rls, c.relforcerowsecurity AS forced,',
    '           EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = c.oid) AS has_policy',
    '    FROM pg_class c',
    '    JOIN pg_namespace n ON n.oid = c.relnamespace',
    "    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = 'tenant_id' AND NOT a.attisdropped",
    "    WHERE c.relkind IN ('r', 'p') AND NOT c.relispartition",
    "      AND n.nspname NOT IN ('pg_catalog', 'information_schema')",
    '  LOOP',
    '    IF NOT (r.rls AND r.forced AND r.has_policy) THEN',
    "      RAISE EXCEPTION 'integrity: % has tenant_id but RLS is not enabled, forced and covered by a policy', r.tbl;",
    '    END IF;',
    '  END LOOP;',
    'END $$;',
  );
  if (existsSync(join(DB, 'checks.sql'))) lines.push(`\\ir ${rel(join(DB, 'checks.sql'))}`);

  lines.push('', 'COMMIT;', '');
  return lines.join('\n');
}

function check() {
  const errors = [];

  if (!existsSync(OUT)) errors.push('bootstrap.sql is missing: run the build');
  else if (read(OUT) !== generate()) errors.push('bootstrap.sql is stale: run the build');

  if (!walk(join(DB, 'models')).some((f) => basename(f).endsWith('schema-migrations.sql'))) {
    errors.push('database/models has no *-schema-migrations.sql model');
  }

  // Migrations: name format, unique contiguous numbering
  const migDir = join(DB, 'migrations');
  const numbers = [];
  for (const f of walk(migDir)) {
    const name = basename(f);
    if (name === '.gitkeep') continue;
    const m = name.match(MIGRATION_RE);
    if (!m) { errors.push(`${rel(f)}: migration name must match MIG-NNN-<kebab-concept>-<YYYYMMDDHHmm>.sql`); continue; }
    numbers.push(Number(m[1]));
  }
  numbers.sort((a, b) => a - b);
  numbers.forEach((n, i) => {
    if (n !== i + 1) errors.push(`migrations: numbering must be unique and contiguous from 001 (found ${String(n).padStart(3, '0')} at position ${i + 1})`);
  });

  // Naming (kebab-case) for database/ and docs/
  for (const base of [DB, join(ROOT, 'docs')]) {
    for (const d of walkDirs(base)) {
      if (!KEBAB_DIR_RE.test(basename(d))) errors.push(`${rel(d)}: directory names must be kebab-case`);
    }
    for (const f of walk(base)) {
      const name = basename(f);
      if (name === '.gitkeep') continue;
      if (!(KEBAB_FILE_RE.test(name) || MIGRATION_RE.test(name) || ADR_RE.test(name))) {
        errors.push(`${rel(f)}: file names must be kebab-case (.sql or .md)`);
      }
    }
  }

  // Mandatory header in every SQL source: line 1 "-- <file name>", line 2 "-- <purpose>"
  for (const f of walk(DB).filter((p) => p.endsWith('.sql'))) {
    const [l1 = '', l2 = ''] = read(f).split('\n');
    if (l1.trim() !== `-- ${basename(f)}`) errors.push(`${rel(f)}: line 1 must be "-- ${basename(f)}"`);
    if (!/^--\s+\S/.test(l2)) errors.push(`${rel(f)}: line 2 must be a short "-- <purpose>" comment`);
  }

  if (errors.length) {
    console.error(`check failed (${errors.length}):\n  - ${errors.join('\n  - ')}`);
    process.exit(1);
  }
  console.log('check passed');
}

function migrate(useDocker) {
  const files = migrations();
  if (!useDocker && !process.env.DATABASE_URL) {
    console.error('DATABASE_URL is not set (or use: migrate --docker)');
    process.exit(1);
  }
  for (const name of files) {
    const sql = read(join(DB, 'migrations', name));
    const res = useDocker
      ? spawnSync('docker', ['compose', 'exec', '-T', 'db', 'sh', '-c',
          'psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'], { input: sql, stdio: ['pipe', 'inherit', 'inherit'] })
      : spawnSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', process.env.DATABASE_URL], { input: sql, stdio: ['pipe', 'inherit', 'inherit'] });
    if (res.status !== 0) {
      console.error(`migration failed: ${name}`);
      process.exit(res.status ?? 1);
    }
    console.log(`ok  ${name}`);
  }
  console.log(`${files.length} migration(s) checked; already-applied ones were skipped by their guard`);
}

const [cmd = 'build', flag] = process.argv.slice(2);
if (cmd === 'build') { writeFileSync(OUT, generate()); console.log(`wrote ${rel(OUT)}`); }
else if (cmd === 'check') check();
else if (cmd === 'migrate') migrate(flag === '--docker');
else { console.error('usage: node build.mjs [build|check|migrate [--docker]]'); process.exit(2); }
