# build.ps1
# Assembles bootstrap.sql from the sources of truth in database/ and validates the repo.
#
# Usage:
#   ./build.ps1 build              regenerate bootstrap.sql
#   ./build.ps1 check              exit 1 if bootstrap.sql is stale or the repo breaks conventions
#   ./build.ps1 migrate            apply pending migrations with psql ($env:DATABASE_URL)
#   ./build.ps1 migrate -Docker    apply pending migrations inside the compose service "db"
#
# Works on Windows PowerShell 5.1 and PowerShell 7+. Output is byte-identical to build.mjs and build.py.

param(
  [Parameter(Position = 0)][ValidateSet('build', 'check', 'migrate')][string]$Command = 'build',
  [switch]$Docker
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Db = Join-Path $Root 'database'
$Out = Join-Path $Root 'bootstrap.sql'
$Utf8 = New-Object System.Text.UTF8Encoding $false
$OutputEncoding = $Utf8   # text piped to psql/docker is sent as UTF-8 (5.1 defaults to ASCII)

$MigrationRe = '^MIG-(\d{3,})-[a-z0-9]+(?:-[a-z0-9]+)*-(\d{12})\.sql$'
$AdrRe = '^ADR-\d{3,}-[a-z0-9]+(?:-[a-z0-9]+)*\.md$'
$KebabFileRe = '^[a-z0-9]+(?:-[a-z0-9]+)*\.(sql|md)$'
$KebabDirRe = '^[a-z0-9]+(?:-[a-z0-9]+)*$'

function Get-Rel([string]$Path) {
  $full = [System.IO.Path]::GetFullPath($Path)
  return $full.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/')
}

function Read-Text([string]$Path) {
  return [System.IO.File]::ReadAllText($Path, $Utf8).Replace("`r`n", "`n")
}

function Get-Files([string]$Dir) {
  if (-not (Test-Path $Dir)) { return @() }
  return @(Get-ChildItem -Path $Dir -Recurse -File | ForEach-Object { $_.FullName })
}

function Get-Dirs([string]$Dir) {
  if (-not (Test-Path $Dir)) { return @() }
  return @(Get-ChildItem -Path $Dir -Recurse -Directory | ForEach-Object { $_.FullName })
}

# Ordered by file name first (numeric prefix is global across schema subfolders), then path.
# Ordinal comparison keeps the order identical to the Node and Python builds.
function Get-SqlFiles([string]$Dir, [string[]]$Exclude = @()) {
  $files = @(Get-Files $Dir | Where-Object {
      $_.EndsWith('.sql') -and ($Exclude -notcontains [System.IO.Path]::GetFileName($_))
    })
  if ($files.Count -eq 0) { return @() }
  $keys = [string[]]($files | ForEach-Object { [System.IO.Path]::GetFileName($_) + [char]0 + (Get-Rel $_) })
  $arr = [string[]]$files
  [Array]::Sort($keys, $arr, [System.StringComparer]::Ordinal)
  return $arr
}

function Get-Migrations {
  $names = @(Get-SqlFiles (Join-Path $Db 'migrations') | ForEach-Object { [System.IO.Path]::GetFileName($_) } |
      Where-Object { $_ -cmatch $MigrationRe })
  return @($names | Sort-Object { [int]([regex]::Match($_, $MigrationRe).Groups[1].Value) })
}

function New-Bootstrap {
  $sections = @(
    @('1. Extensions', @(Join-Path $Db 'extensions.sql')),
    @('2. Roles (run as superuser)', @(Join-Path (Join-Path $Db 'security') 'roles.sql')),
    @('3. Schemas (switches to the owner role at the end)', @(Join-Path $Db 'schemas.sql')),
    @('4. Functions', @(Get-SqlFiles (Join-Path $Db 'functions'))),
    @('5. Models', @(Get-SqlFiles (Join-Path $Db 'models'))),
    @('6. Triggers', @(Get-SqlFiles (Join-Path $Db 'triggers'))),
    @('7. Grants', @(Get-SqlFiles (Join-Path $Db 'security') @('roles.sql'))),
    @('8. Reference seeds', @(Get-SqlFiles (Join-Path $Db 'seeds') @('dev.sql')))
  )
  $lines = New-Object System.Collections.Generic.List[string]
  @(
    '-- bootstrap.sql',
    '-- GENERATED FILE. Do not edit by hand: change the sources in database/ and run the build.',
    '-- Creates a database from scratch in one transaction. Only for new environments;',
    '-- existing databases receive migrations (database/migrations/).',
    '',
    '\set ON_ERROR_STOP on',
    '',
    'BEGIN;',
    'SET LOCAL check_function_bodies = off;',
    "SET LOCAL client_min_messages = 'warning';"
  ) | ForEach-Object { $lines.Add($_) }

  foreach ($s in $sections) {
    $lines.Add(''); $lines.Add("-- $($s[0])")
    $present = @($s[1] | Where-Object { $_ -and (Test-Path $_) })
    if ($present.Count -eq 0) { $lines.Add('-- (none)') }
    foreach ($f in $present) { $lines.Add("\ir $(Get-Rel $f)") }
  }

  $lines.Add(''); $lines.Add('RESET ROLE;'); $lines.Add('')
  $lines.Add('-- 9. Migration baseline: this schema already contains every migration below')
  $ids = @(Get-Migrations | ForEach-Object { $_.Substring(0, $_.Length - 4) })
  if ($ids.Count -eq 0) { $lines.Add('-- (no migrations yet)') }
  else {
    $lines.Add('INSERT INTO public.schema_migrations (id, applied_by) VALUES')
    for ($i = 0; $i -lt $ids.Count; $i++) {
      $sep = if ($i -lt $ids.Count - 1) { ',' } else { '' }
      $lines.Add("  ('$($ids[$i])', 'bootstrap')$sep")
    }
    $lines.Add('ON CONFLICT (id) DO NOTHING;')
  }

  @(
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
    'END $$;'
  ) | ForEach-Object { $lines.Add($_) }
  $checks = Join-Path $Db 'checks.sql'
  if (Test-Path $checks) { $lines.Add("\ir $(Get-Rel $checks)") }

  $lines.Add(''); $lines.Add('COMMIT;'); $lines.Add('')
  return [string]::Join("`n", $lines)
}

function Invoke-Check {
  $errors = New-Object System.Collections.Generic.List[string]
  if (-not (Test-Path $Out)) { $errors.Add('bootstrap.sql is missing: run the build') }
  elseif ((Read-Text $Out) -cne (New-Bootstrap)) { $errors.Add('bootstrap.sql is stale: run the build') }

  if (-not (Get-Files (Join-Path $Db 'models') | Where-Object { $_.EndsWith('schema-migrations.sql') })) {
    $errors.Add('database/models has no *-schema-migrations.sql model')
  }

  $numbers = New-Object System.Collections.Generic.List[int]
  foreach ($f in Get-Files (Join-Path $Db 'migrations')) {
    $name = [System.IO.Path]::GetFileName($f)
    if ($name -eq '.gitkeep') { continue }
    $m = [regex]::Match($name, $MigrationRe)
    if (-not $m.Success) { $errors.Add("$(Get-Rel $f): migration name must match MIG-NNN-<kebab-concept>-<YYYYMMDDHHmm>.sql"); continue }
    $numbers.Add([int]$m.Groups[1].Value)
  }
  $sorted = @($numbers | Sort-Object)
  for ($i = 0; $i -lt $sorted.Count; $i++) {
    if ($sorted[$i] -ne $i + 1) {
      $errors.Add(('migrations: numbering must be unique and contiguous from 001 (found {0:D3} at position {1})' -f $sorted[$i], ($i + 1)))
    }
  }

  foreach ($base in @($Db, (Join-Path $Root 'docs'))) {
    foreach ($d in Get-Dirs $base) {
      if ([System.IO.Path]::GetFileName($d) -cnotmatch $KebabDirRe) { $errors.Add("$(Get-Rel $d): directory names must be kebab-case") }
    }
    foreach ($f in Get-Files $base) {
      $name = [System.IO.Path]::GetFileName($f)
      if ($name -eq '.gitkeep') { continue }
      if (-not ($name -cmatch $KebabFileRe -or $name -cmatch $MigrationRe -or $name -cmatch $AdrRe)) {
        $errors.Add("$(Get-Rel $f): file names must be kebab-case (.sql or .md)")
      }
    }
  }

  foreach ($f in @(Get-Files $Db | Where-Object { $_.EndsWith('.sql') })) {
    $name = [System.IO.Path]::GetFileName($f)
    $content = (Read-Text $f).Split("`n")
    $l1 = if ($content.Count -gt 0) { $content[0] } else { '' }
    $l2 = if ($content.Count -gt 1) { $content[1] } else { '' }
    if ($l1.Trim() -cne "-- $name") { $errors.Add("$(Get-Rel $f): line 1 must be `"-- $name`"") }
    if ($l2 -cnotmatch '^--\s+\S') { $errors.Add("$(Get-Rel $f): line 2 must be a short `"-- <purpose>`" comment") }
  }

  if ($errors.Count -gt 0) {
    [Console]::Error.WriteLine("check failed ($($errors.Count)):`n  - " + [string]::Join("`n  - ", $errors))
    exit 1
  }
  Write-Output 'check passed'
}

function Invoke-Migrate {
  $files = @(Get-Migrations)
  if (-not $Docker -and -not $env:DATABASE_URL) {
    [Console]::Error.WriteLine('DATABASE_URL is not set (or use: migrate -Docker)'); exit 1
  }
  foreach ($name in $files) {
    $sql = Read-Text (Join-Path (Join-Path $Db 'migrations') $name)
    if ($Docker) {
      $sql | docker compose exec -T db sh -c 'psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
    } else {
      $sql | psql -X -q -v ON_ERROR_STOP=1 $env:DATABASE_URL
    }
    if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine("migration failed: $name"); exit $LASTEXITCODE }
    Write-Output "ok  $name"
  }
  Write-Output "$($files.Count) migration(s) checked; already-applied ones were skipped by their guard"
}

switch ($Command) {
  'build' { [System.IO.File]::WriteAllText($Out, (New-Bootstrap), $Utf8); Write-Output 'wrote bootstrap.sql' }
  'check' { Invoke-Check }
  'migrate' { Invoke-Migrate }
}
