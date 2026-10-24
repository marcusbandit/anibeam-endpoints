# anibeam-endpoints

Endpoint definitions for [AniBeam](https://github.com/marcusbandit/AniBeam). The endpoints come in groups, and a user adds each group in AniBeam on its own by pasting the raw URL of its index, then installs endpoints from it one at a time. The format and the reasons behind it are in AniBeam's spec, `docs/superpowers/specs/2026-10-24-endpoint-repos.md` (issue #143).

A definition is data. Nothing in it runs. Each endpoint kind (`nyaa`, `rss`, `tosho`) is code inside AniBeam's core.

## Layout

- `groups.json`: the groups, each with the name AniBeam shows and whether its endpoints are NSFW.
- `endpoints/<group>/<id>.json`: one definition per endpoint, checked against `schema/endpoint.schema.json`. Ids are unique across groups, and every definition's `nsfw` matches its group.
- `index/<group>.json`: built and signed by CI from `endpoints/<group>/`. Never edit one by hand. It holds the index as base64 in `payload` and the ed25519 signature over those bytes in `signature`; the index carries every definition whole and a `serial` that only goes up. `scripts/verify.sh index/<group>.json` checks one and prints its index.

## Groups

| Group | Index to add in AniBeam |
| --- | --- |
| general | `https://raw.githubusercontent.com/marcusbandit/anibeam-endpoints/main/index/general.json` |
| nsfw | `https://raw.githubusercontent.com/marcusbandit/anibeam-endpoints/main/index/nsfw.json` |

A new group is a line in `groups.json` and a folder under `endpoints/`.

## Signing key

```
ed25519:vJd1BUBvBB04CgVz34lWbtpG66tJ7caMziu9P76S/t4=
```

Every group is signed with it. AniBeam shows this key when a group is added and refuses an index signed by any other. CI signs with the `ENDPOINTS_SIGNING_KEY` repo secret.

## Adding an endpoint

1. Check the site by hand: does a search need an API key, a token, a login, or nothing; what rate it tolerates.
2. Write `endpoints/<group>/<id>.json`: `general` for most things, `nsfw` for adult sites. Put each `auth` key in the URL as `{key}`, next to `{query}`.
3. Run `scripts/check.sh` (needs `jq` and `check-jsonschema`).
4. Open a PR. CI checks every file and refuses a changed definition whose `version` did not go up.
5. Merge. CI rebuilds and signs the group's index and commits it.

## Visibility

AniBeam reads the index over a plain raw URL, so the repo has to be public before an app can add it.
