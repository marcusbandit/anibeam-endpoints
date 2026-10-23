#!/usr/bin/env bash
# Builds repo.json from endpoints/ and signs it.
# Usage: scripts/build-index.sh <ed25519-private-key.pem>
# repo.json holds the index as base64 (payload) and the base64 ed25519 signature over
# the payload's decoded bytes, so the app fetches one file and checks exactly what CI signed.
set -euo pipefail
cd "$(dirname "$0")/.."
key=${1:?usage: scripts/build-index.sh <private-key.pem>}

pub=$(openssl pkey -in "$key" -pubout -outform DER | tail -c 32 | base64 -w0)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

shopt -s nullglob
files=(endpoints/*.json)
if ((${#files[@]})); then
  jq -s 'sort_by(.id)' "${files[@]}" > "$tmp/endpoints.json"
else
  echo '[]' > "$tmp/endpoints.json"
fi

jq -c --arg key "ed25519:$pub" --argjson serial "$(date +%s)" \
  '{name: "Marcus'"'"'s endpoints", key: $key, serial: $serial, endpoints: .}' \
  "$tmp/endpoints.json" > "$tmp/index.json"

openssl pkeyutl -sign -inkey "$key" -rawin -in "$tmp/index.json" -out "$tmp/sig.bin"

jq -n --arg payload "$(base64 -w0 "$tmp/index.json")" --arg signature "$(base64 -w0 "$tmp/sig.bin")" \
  '{format: "anibeam-endpoint-repo", version: 1, payload: $payload, signature: $signature}' > repo.json

echo "repo.json: $(jq length "$tmp/endpoints.json") endpoints, key ed25519:$pub"
