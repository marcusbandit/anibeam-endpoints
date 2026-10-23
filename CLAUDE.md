# CLAUDE.md

Endpoint definitions for AniBeam (`~/Projects/anibeam`). The format, the trust model and the reasons are in AniBeam's spec, `docs/superpowers/specs/2026-10-24-endpoint-repos.md`, issue marcusbandit/AniBeam#143. Read it before changing the format.

## Adding an endpoint

The owner adds endpoints one at a time, each checked by hand. The ask is usually "add <site>".

1. Find out what a search needs: nothing, an API key, a token, or a login. Find where a user gets the key, for `help_url`. Note the rate the site tolerates and whether it is known to be blocked on some networks (then it may need `front`).
2. Write `endpoints/<id>.json` against `schema/endpoint.schema.json`. Each `auth` key appears in `url` as `{key}`, beside `{query}`. Never put a real key in a file.
3. `scripts/check.sh` must pass. It needs `jq` and `check-jsonschema` (`uvx check-jsonschema` works).
4. Try the search for real once AniBeam's core reads repos, with `anibeam-cli --root <sandbox>` from the AniBeam checkout.
5. Branch `feat/<id>`, open a PR, merge with `gh pr merge --squash --delete-branch` once CI is green. CI rebuilds and signs `repo.json`.

Changing an existing definition means raising its `version`; CI refuses it otherwise.

## Rules

- A definition is data. No commands, scripts or code, ever. That is what keeps AniBeam allowed on Google Play.
- Never edit `repo.json` by hand; CI owns it. `scripts/verify.sh` checks its signature and prints the index.
- The signing key lives in the `ENDPOINTS_SIGNING_KEY` repo secret, with the owner's copy at `~/.config/anibeam-endpoints/signing-key.pem`. Never print it, commit it or rotate it without asking: rotating breaks every install that pinned the old key.
- Every change goes through a PR. Never push to `main`.
- Use `git -C <abs path>` rather than `cd`; `cd` is a zoxide alias here and fails silently.
