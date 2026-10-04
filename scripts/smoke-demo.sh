#!/usr/bin/env bash
set -euo pipefail

log="$(mktemp)"
bootstrap="$(mktemp)"
request_body="$(mktemp)"
server_pid=''

cleanup() {
  if [ -n "$server_pid" ]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -f "$log" "$bootstrap" "$request_body"
}
trap cleanup EXIT INT TERM

dune exec cutline -- demo --port 0 >"$log" 2>&1 &
server_pid=$!

for attempt in $(seq 1 50); do
  if grep -q '^I serve the local atlas at http://127\.0\.0\.1:' "$log"; then
    break
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    cat "$log" >&2
    printf '%s\n' 'I could not keep the local demo server running.' >&2
    exit 1
  fi
  sleep 0.1
done

port="$(sed -n 's/^I serve the local atlas at http:\/\/127\.0\.0\.1:\([0-9][0-9]*\)\/$/\1/p' "$log")"
if [ -z "$port" ]; then
  cat "$log" >&2
  printf '%s\n' 'I could not find the ephemeral demo port.' >&2
  exit 1
fi

base="http://127.0.0.1:$port"
curl --fail --silent --show-error "$base/" >/dev/null
curl --fail --silent --show-error "$base/style.css" >/dev/null
curl --fail --silent --show-error "$base/boot.js" >/dev/null
curl --fail --silent --show-error "$base/main.js" >/dev/null
curl --fail --silent --show-error "$base/api/bootstrap" --output "$bootstrap"

node - "$bootstrap" "$request_body" <<'NODE'
const fs = require("node:fs");
const bootstrap = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
if (bootstrap.schema_version !== 1 || bootstrap.nodes.length !== 1513 || bootstrap.segments.length !== 1555) {
  throw new Error("I found an unexpected local graph bootstrap.");
}
if (bootstrap.closed_segments.length !== 1) {
  throw new Error("I found no initial hypothetical closure.");
}
fs.writeFileSync(process.argv[3], JSON.stringify({
  origin: bootstrap.analysis.origin,
  destination: bootstrap.analysis.destination,
  closed: bootstrap.closed_segments
}));
NODE

curl --fail --silent --show-error \
  --header 'content-type: application/json' \
  --data-binary "@$request_body" \
  "$base/api/analyze" >/dev/null

status="$(curl --silent --output /dev/null --write-out '%{http_code}' --header 'Host: example.test' "$base/api/bootstrap")"
if [ "$status" != '403' ]; then
  printf 'I expected a forged host to return 403, not %s.\n' "$status" >&2
  exit 1
fi

printf '%s\n' 'I verified the local assets, bootstrap graph, analysis route, and host check.'
