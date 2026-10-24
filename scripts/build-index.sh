#!/usr/bin/env bash
# Builds and signs one index per group in groups.json: endpoints/<group>/ becomes index/<group>.json.
# Usage: scripts/build-index.sh <ed25519-private-key.pem>
# Each index file holds the index as base64 (payload) and the base64 ed25519 signature over
# the payload's decoded bytes, so the app fetches one file and checks exactly what CI signed.
# Every group is signed with the same key; a user adds each group by its own URL.
set -euo pipefail
cd "$(dirname "$0")/.."
key=${1:?usage: scripts/build-index.sh <private-key.pem>}

pub=$(openssl pkey -in "$key" -pubout -outform DER | tail -c 32 | base64 -w0)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p index

shopt -s nullglob
# A group dropped from groups.json loses its index too, so its raw URL stops serving a frozen list.
for f in index/*.json; do
  jq -e --arg g "$(basename "$f" .json)" 'has($g)' groups.json >/dev/null || rm -f "$f"
done

while read -r group; do
  files=(endpoints/"$group"/*.json)
  if ((${#files[@]})); then
    jq -s 'sort_by(.id)' "${files[@]}" > "$tmp/endpoints.json"
  else
    echo '[]' > "$tmp/endpoints.json"
  fi

  jq -c --arg key "ed25519:$pub" --argjson serial "$(date +%s)" \
    --argjson group "$(jq -c --arg g "$group" '.[$g]' groups.json)" \
    '{name: $group.name, nsfw: $group.nsfw, key: $key, serial: $serial, endpoints: .}' \
    "$tmp/endpoints.json" > "$tmp/index.json"

  openssl pkeyutl -sign -inkey "$key" -rawin -in "$tmp/index.json" -out "$tmp/sig.bin"

  jq -n --arg payload "$(base64 -w0 "$tmp/index.json")" --arg signature "$(base64 -w0 "$tmp/sig.bin")" \
    '{format: "anibeam-endpoint-repo", version: 1, payload: $payload, signature: $signature}' > "index/$group.json"

  echo "index/$group.json: $(jq length "$tmp/endpoints.json") endpoints, key ed25519:$pub"
done < <(jq -r 'keys[]' groups.json)
