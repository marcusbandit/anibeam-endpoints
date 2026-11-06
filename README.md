# anibeam-endpoints

Endpoint definitions for [AniBeam](https://github.com/marcusbandit/AniBeam). The endpoints come in groups, and a user adds each group in AniBeam on its own by pasting the raw URL of its index, then installs endpoints from it one at a time. The format and the reasons behind it are in AniBeam's spec, `docs/superpowers/specs/2026-10-24-endpoint-repos.md` (issue #143).

A definition is data. Nothing in it runs. Each endpoint kind is code inside AniBeam's core, named for the shape of what it reads, never for a site:

- `filtered-rss`: a bare site address the core turns into an RSS search with `category` and `filter`, asked again unfiltered when the filter finds nothing
- `rss`: any RSS feed whose `url` holds `{query}`
- `json-feed`: a JSON feed of torrent entries in one fixed layout, its `url` holding `{query}`
- `torznab`: an indexer's torznab search, read as RSS

A definition can also carry, as data:

- `trusted_groups`: release groups best fit prefers out of the box
- for an `rss` endpoint, `quality_local` (its search matches post text only, so quality words narrow the results in AniBeam instead), `one_variant` (a subscription that names no variant excludes this word) and `show_feed` (patterns that read a show's slug from a result's post page, and the show's own feed on the same host)

Kinds were renamed in definition version 2 (`nyaa` became `filtered-rss`, `tosho` became `json-feed`, AniBeam#602); those definitions and the ones with the fields above need AniBeam 2.4.0 or newer (`min_core`).

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
2. Write `endpoints/<group>/<id>.json`: `general` for most things, `nsfw` for adult sites. Put each `auth` key in the URL as `{key}`, next to `{query}`. The host stays literal, except that a `torznab` URL may name the user's own Prowlarr or Jackett as `{host}`, its whole authority, from a non-secret `host` field; only that form may be plain `http://`.
3. Run `scripts/check.sh` (needs `jq` and `check-jsonschema`).
4. Open a PR. CI checks every file and refuses a changed definition whose `version` did not go up.
5. Merge. CI rebuilds and signs the group's index and commits it.

## Visibility

AniBeam reads the index over a plain raw URL, so the repo has to be public before an app can add it.
