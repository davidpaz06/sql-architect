#!/usr/bin/env bash
# verify-blueprints.sh [blueprint ...]
# Maintenance check for this skill: for each blueprint, assembles a throwaway repo with the Node and Python
# builds, checks both produce the same bootstrap, runs the build check, starts postgres:18 with the bootstrap
# (entrypoint = run 1), runs it again (idempotency), runs the dev seed twice, and reports shared files that
# drifted from templates/database. Requires bash, node, python3 and Docker.
set -euo pipefail

SKILL="$(cd "$(dirname "$0")/.." && pwd)"
BLUEPRINTS=("$@")
if [ ${#BLUEPRINTS[@]} -eq 0 ]; then
  for d in "$SKILL"/references/blueprints/*/; do BLUEPRINTS+=("$(basename "$d")"); done
fi
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT
FAILED=0

for bp in "${BLUEPRINTS[@]}"; do
  echo "== $bp"
  repo="$WORK/$bp"; mkdir -p "$repo"
  cp -r "$SKILL/references/blueprints/$bp/database" "$SKILL/references/blueprints/$bp/docs" "$repo/"
  cp "$SKILL/templates/build.mjs" "$SKILL/templates/build.py" "$repo/"

  (cd "$repo" && node build.mjs build >/dev/null && cp bootstrap.sql bootstrap.node.sql \
     && python3 build.py build >/dev/null && cmp -s bootstrap.node.sql bootstrap.sql && rm bootstrap.node.sql) \
     || { echo "   FAIL: node and python builds differ"; FAILED=1; continue; }
  (cd "$repo" && node build.mjs check >/dev/null) || { echo "   FAIL: build check"; (cd "$repo" && node build.mjs check) || true; FAILED=1; continue; }

  # Shared files that drifted from the templates. Files that blueprints customize by design are skipped.
  (cd "$SKILL/templates/database" && find . -type f -name '*.sql') | while read -r f; do
    case "$f" in ./checks.sql|./extensions.sql|./security/grants.sql|./triggers/updated-at.sql) continue ;; esac
    if [ -f "$repo/database/$f" ] && ! cmp -s "$SKILL/templates/database/$f" "$repo/database/$f"; then
      echo "   note: database/${f#./} differs from templates"
    fi
  done

  name="sqlarch-verify-$bp"
  docker rm -f "$name" >/dev/null 2>&1 || true
  docker run -d --name "$name" -e POSTGRES_PASSWORD=verify -e POSTGRES_DB=app -e APP_ENV=development \
    -e DB_OWNER_PASSWORD=verify -e DB_API_PASSWORD=verify -e DB_WORKER_PASSWORD=verify -e DB_READONLY_PASSWORD=verify \
    -v "$repo/bootstrap.sql:/docker-entrypoint-initdb.d/01-bootstrap.sql:ro" \
    -v "$repo/database:/docker-entrypoint-initdb.d/database:ro" postgres:18 >/dev/null
  for _ in $(seq 1 60); do
    if docker exec "$name" pg_isready -h 127.0.0.1 -U postgres -d app >/dev/null 2>&1; then break; fi
    if [ "$(docker inspect -f '{{.State.Running}}' "$name")" != "true" ]; then break; fi
    sleep 1
  done
  sleep 1
  if docker logs "$name" 2>&1 | grep -qE 'ERROR|FATAL'; then
    echo "   FAIL: bootstrap"; docker logs "$name" 2>&1 | grep -E 'ERROR|FATAL' | head -5; FAILED=1
  elif ! docker exec "$name" psql -X -q -v ON_ERROR_STOP=1 -U postgres -d app \
         -f /docker-entrypoint-initdb.d/01-bootstrap.sql >/dev/null 2>"$WORK/err"; then
    echo "   FAIL: second bootstrap run (not idempotent)"; head -5 "$WORK/err"; FAILED=1
  elif [ -f "$repo/database/seeds/dev.sql" ] && ! { docker exec -i "$name" psql -X -q -U postgres -d app < "$repo/database/seeds/dev.sql" >/dev/null \
         && docker exec -i "$name" psql -X -q -U postgres -d app < "$repo/database/seeds/dev.sql" >/dev/null; }; then
    echo "   FAIL: dev seed"; FAILED=1
  else
    tables=$(docker exec "$name" psql -X -At -U postgres -d app -c \
      "SELECT count(*) FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema')")
    echo "   ok ($tables tables, bootstrap x2, dev seed x2)"
  fi
  docker rm -f "$name" >/dev/null
done

exit $FAILED
