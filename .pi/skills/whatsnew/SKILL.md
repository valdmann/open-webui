---
name: whatsnew
description: Read this when the user asks what's new upstream. The answer can be surprisingly tricky.
---

## So, what's new upstream?

Run the script next to this file:

```sh
.pi/skills/whatsnew/whatsnew.sh
```

It git fetches, then prints the release notes added upstream, each bullet marked:

- `NEW` — cited commits are not in our history; this is genuinely new for us.
- `have` — already in our history; only the headline is shown.
- `NEW?` — cites nothing resolvable; shown in full but verify by hand.

For replaying history (e.g. answering "what did we skip at the last merge?"):
`whatsnew.sh HEAD^1 v0.11.3` — any base and target work. Quirks to expect:

- A range where upstream added no changelog bullets prints a note instead of
  output — early dev merges carry commits but no release notes.
- Old sections of the changelog use indented sub-bullets (dependency upgrades
  and the like); these are included, citing nothing resolvable, so they show
  as `NEW?`.
- Deep replays reaching far back are slow: every cited PR number is resolved
  by grepping the whole history. Prefer ranges since your last merge point.

## Why the script does what it does

The `origin` remote points to the upstream repo for open-webui. `origin/main` is the release branch; `origin/dev` carries unreleased work that we sometimes merge early for bugfixes. This matters because it makes the naive answers wrong:

- **`git log` is unusable.** Upstream pollutes history with commits titled just `refac`; subject lines cannot always be trusted to describe content.
- **The CHANGELOG.md diff is the only readable summary** (release notes in prose), **but it overstates the delta.** The changelog is written on main at release time, so a fix we already picked up via an early dev merge still appears as a new entry. When this happened to us, the changelog listed ~40% more news than we were actually missing.
- **So each bullet is resolved against our history by ancestry.** Bullets cite commit hashes and PR numbers; because dev merges carry the identical commits (not cherry-picks), `git merge-base --is-ancestor` against our history is exact. PR numbers are resolved to commits via upstream's convention of ending subjects with `(#N)` — where that convention breaks, the bullet is marked `NEW?` rather than guessed at.

Remaining imperfections: a `have` can rarely be wrong if a PR contains commits that don't cite its number, and bullets citing only issue links (`issues/N`, unresolvable) are marked `NEW?`.
