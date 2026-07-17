#!/usr/bin/env bash
# Repro: dynamic API route over-matches (`:id*`) and dispatches to the [id] handler with
# undefined params -> unhandled 500 instead of 404.
# Prereq: `yarn install` at repo root. Node >= 22.18.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CLI="$REPO_ROOT/packages/cli/src/bin.js"
cd "$HERE/fixture"

node "$CLI" build > /tmp/gwd-repro-api-build.log 2>&1
node "$CLI" serve > /tmp/gwd-repro-api-serve.log 2>&1 &
SPID=$!
trap 'kill $SPID 2>/dev/null' EXIT
for i in $(seq 1 40); do curl -s -o /dev/null http://localhost:8080/ && break; sleep 0.5; done

for r in "/api/users/42" "/api/users/42/99/x" "/api/users" "/api/users/"; do
  printf '%-24s -> ' "GET $r"
  curl -s --path-as-is -w " [%{http_code}]\n" "http://localhost:8080$r"
done
echo "--- server stderr (TypeError from the over-matched requests) ---"
grep -A1 "Cannot read properties of undefined" /tmp/gwd-repro-api-serve.log | head -4
