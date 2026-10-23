#!/usr/bin/env bash
# Checks every endpoint definition. Exits non-zero on the first problem it reports.
# Usage: scripts/check.sh [base-ref]   base-ref: compare versions against it (CI passes origin/main)
set -euo pipefail
cd "$(dirname "$0")/.."
base=${1:-}
fail=0
err() { echo "error: $*" >&2; fail=1; }

shopt -s nullglob
files=(endpoints/*.json)

if ((${#files[@]})); then
  check-jsonschema --schemafile schema/endpoint.schema.json "${files[@]}" || fail=1
fi

declare -A seen
for f in "${files[@]}"; do
  id=$(jq -r .id "$f")
  [[ "endpoints/$id.json" == "$f" ]] || err "$f: id \"$id\" does not match the file name"
  [[ -z "${seen[$id]:-}" ]] || err "$f: duplicate id \"$id\""
  seen[$id]=1

  url=$(jq -r .url "$f")
  if [[ $(jq -r .kind "$f") == nyaa ]]; then
    # The core appends ?page=rss&q=...&c=...&f=... to a nyaa url itself.
    [[ "$url" != *"?"* && "$url" != *"{query}"* ]] || err "$f: a nyaa url is the bare site, with no query string"
  else
    [[ "$url" == *"{query}"* ]] || err "$f: url has no {query} placeholder"
  fi
  while read -r key; do
    [[ -z "$key" || "$url" == *"{$key}"* ]] || err "$f: auth key \"$key\" never appears in url"
  done < <(jq -r '.auth[].key' "$f")

  if [[ -n "$base" ]] && old=$(git show "$base:$f" 2>/dev/null); then
    if ! diff -q <(jq -S . <<<"$old") <(jq -S . "$f") >/dev/null; then
      ov=$(jq .version <<<"$old"); nv=$(jq .version "$f")
      ((nv > ov)) || err "$f: changed but version did not go up ($ov -> $nv)"
    fi
  fi
done

exit $fail
