#!/usr/bin/env bash
# Builds index.json from endpoints/ and signs it.
# Usage: scripts/build-index.sh <ed25519-private-key.pem>
# Writes index.json and index.json.sig (base64 of the raw 64-byte ed25519 signature
# over the exact bytes of index.json).
set -euo pipefail
cd "$(dirname "$0")/.."
key=${1:?usage: scripts/build-index.sh <private-key.pem>}

pub=$(openssl pkey -in "$key" -pubout -outform DER | tail -c 32 | base64 -w0)

shopt -s nullglob
entries=()
for f in endpoints/*.json; do
  sum=$(sha256sum "$f" | cut -d' ' -f1)
  entries+=("$(jq -c --arg file "$f" --arg sha "$sum" '{
    id, name, version, lang, kind,
    auth: [.auth[].key],
    nsfw: (.nsfw // false),
    min_core,
    file: $file,
    sha256: $sha
  }' "$f")")
done

printf '%s\n' "${entries[@]}" | jq -s --arg key "ed25519:$pub" '{
  format: "anibeam-endpoint-repo",
  version: 1,
  name: "Marcus'"'"'s endpoints",
  key: $key,
  endpoints: (map(select(. != null)) | sort_by(.id))
}' > index.json

openssl pkeyutl -sign -inkey "$key" -rawin -in index.json | base64 -w0 > index.json.sig
echo >> index.json.sig
echo "index.json: $(jq '.endpoints | length' index.json) endpoints, key ed25519:$pub"
