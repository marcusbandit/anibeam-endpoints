#!/usr/bin/env bash
# Checks an index file's signature against its own key and prints the decoded index.
# The app does the same, then pins the key the first time a repo is added.
# Usage: scripts/verify.sh [index/<group>.json]
set -euo pipefail
file=${1:-"$(dirname "$0")/../index/general.json"}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

jq -r .payload "$file" | base64 -d > "$tmp/index.json"
jq -r .signature "$file" | base64 -d > "$tmp/sig.bin"
raw=$(jq -r '.key | sub("^ed25519:"; "")' "$tmp/index.json")
# An ed25519 public key in DER is a fixed 12-byte header plus the raw 32 bytes.
{ printf '\x30\x2a\x30\x05\x06\x03\x2b\x65\x70\x03\x21\x00'; base64 -d <<<"$raw"; } > "$tmp/pub.der"
openssl pkeyutl -verify -pubin -keyform DER -inkey "$tmp/pub.der" -rawin \
  -in "$tmp/index.json" -sigfile "$tmp/sig.bin" >/dev/null
echo "signature ok"
jq . "$tmp/index.json"
