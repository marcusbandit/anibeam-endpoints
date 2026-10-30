#!/usr/bin/env bash
# Checks every endpoint definition. Exits non-zero on the first problem it reports.
# Usage: scripts/check.sh [base-ref]   base-ref: compare versions against it (CI passes origin/main)
set -euo pipefail
cd "$(dirname "$0")/.."
base=${1:-}
fail=0
err() { echo "error: $*" >&2; fail=1; }

shopt -s nullglob
jq -e 'type == "object" and length > 0 and all(to_entries[];
         (.key | test("^[a-z0-9][a-z0-9-]*$")) and (.value.name | type == "string" and length > 0)
         and (.value.nsfw | type == "boolean"))' groups.json >/dev/null \
  || err "groups.json: each group needs a lower-case key, a name and a boolean nsfw"
for stray in endpoints/*.json endpoints/*/*/; do err "$stray: a definition lives directly in endpoints/<group>/"; done
for dir in endpoints/*/; do
  g=$(basename "$dir")
  jq -e --arg g "$g" 'has($g)' groups.json >/dev/null || err "endpoints/$g/: no group \"$g\" in groups.json"
done
files=(endpoints/*/*.json)

if ((${#files[@]})); then
  check-jsonschema --schemafile schema/endpoint.schema.json "${files[@]}" || fail=1
fi

declare -A seen
for f in "${files[@]}"; do
  id=$(jq -r .id "$f")
  group=$(basename "$(dirname "$f")")
  [[ "endpoints/$group/$id.json" == "$f" ]] || err "$f: id \"$id\" does not match the file name"
  # Ids are unique across groups, so an id names one endpoint wherever it is installed from.
  [[ -z "${seen[$id]:-}" ]] || err "$f: duplicate id \"$id\""
  want=$(jq --arg g "$group" '.[$g].nsfw // false' groups.json)
  [[ $(jq '.nsfw // false' "$f") == "$want" ]] || err "$f: nsfw must be $want in group \"$group\""
  seen[$id]=1

  url=$(jq -r .url "$f")
  kind=$(jq -r .kind "$f")
  if [[ $kind == nyaa ]]; then
    # The core appends ?page=rss&q=...&c=...&f=... to a nyaa url itself.
    [[ "$url" != *"?"* && "$url" != *"{query}"* ]] || err "$f: a nyaa url is the bare site, with no query string"
  else
    [[ "$url" == *"{query}"* ]] || err "$f: url has no {query} placeholder"
  fi
  while read -r key; do
    [[ -z "$key" || "$url" == *"{$key}"* ]] || err "$f: auth key \"$key\" never appears in url"
  done < <(jq -r '.auth[].key' "$f")
  # Every placeholder is {query} or an auth key, as the core reads them: from a { to the next }.
  while read -r p; do
    [[ -z "$p" || "$p" == query ]] || jq -e --arg p "$p" 'any(.auth[]; .key == $p)' "$f" >/dev/null \
      || err "$f: url has {$p}, which is neither {query} nor an auth key"
  done < <(jq -r '.url | [scan("\\{([^}]*)\\}")[0]] | .[]' "$f")

  # The host is literal, so a credential cannot pick where it goes. The one exception is a
  # torznab url whose whole authority is {host}: the person's own Prowlarr or Jackett, from a
  # field they can see. The schema allows plain http:// only in that form.
  rest=${url#*://}
  authority=${rest%%[/?#]*}
  if [[ "$authority" == "{host}" ]]; then
    [[ $kind == torznab ]] || err "$f: only a torznab url may name its host as {host}"
    jq -e 'any(.auth[]; .key == "host" and .secret)' "$f" >/dev/null \
      && err "$f: the host auth field must not be secret"
  else
    host=${authority##*@}
    host=${host%%:*}
    [[ -n "$host" ]] || err "$f: url has no host"
    [[ "$host" != *"{"* ]] || err "$f: a placeholder in the host"
  fi

  # Found by id, not path, so a definition moved between groups still has to raise its version.
  oldpath=$([[ -n "$base" ]] && git ls-tree -r --name-only "$base" -- endpoints | awk -F/ -v n="$id.json" '$NF == n' | head -1 || true)
  if [[ -n "$oldpath" ]] && old=$(git show "$base:$oldpath" 2>/dev/null); then
    if ! diff -q <(jq -S . <<<"$old") <(jq -S . "$f") >/dev/null; then
      ov=$(jq .version <<<"$old"); nv=$(jq .version "$f")
      ((nv > ov)) || err "$f: changed but version did not go up ($ov -> $nv)"
    fi
  fi
done

exit $fail
