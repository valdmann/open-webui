---
name: whatsnew
description: Read this when the user asks what's new upstream. The answer can be surprisingly tricky.
---

## So, what's new upstream?

Run the script next to this file:

```sh
.pi/skills/whatsnew/whatsnew.sh [<base> [<target>]]
```

Defaults to comparing `HEAD` with `origin/main`. Point it at `origin/dev` for
unreleased work:

```sh
.pi/skills/whatsnew/whatsnew.sh HEAD origin/dev
```

It git fetches, then reports on everything reachable from `<target>` but not
`<base>`, in two parts:

1. Release-note bullets added upstream (the CHANGELOG.md diff), each marked:
   - `NEW` — cited commits are not in our history; this is genuinely new for us.
   - `have` — already in our history (typically via an early dev merge); only
     the headline is shown.
   - `NEW?` — cites nothing resolvable; shown in full but verify by hand.
2. Every commit in the range that no bullet cites, listed by subject under
   `== not mentioned in the changelog`. The changelog is a curated summary, not
   a ledger, so this completes its coverage; bare-noise subjects (`refac`,
   `chore: format`) are aggregated to a count instead of listed. Mid-cycle dev
   runs have no bullets, so this section is the whole answer there.

For replaying history (e.g. answering "what did we skip at the last merge?"):
`whatsnew.sh HEAD^1 v0.11.3` — any base and target work. Quirks to expect:

- A range where upstream added no changelog bullets still lists the commits
  themselves in part 2 (early dev merges carry commits but no release notes).
- Old sections of the changelog use indented sub-bullets (dependency upgrades
  and the like); these are included as `NEW?`.
- Deep replays are slow: every cited PR number is resolved by grepping the
  whole history. Prefer ranges since your last merge point.

## Why the script does what it does

The `origin` remote points to the upstream repo for open-webui. `origin/main`
is the release branch; `origin/dev` carries unreleased work that we sometimes
merge early for bugfixes. This matters because it makes the naive answers wrong:

- **`git log` alone is unusable.** Upstream squashes everything onto dev
  without merge commits, and roughly 70% of subjects in a large cycle are just
  `refac`; subject lines cannot be trusted to summarize content.
- **The changelog diff alone overstates *and* understates.** It overstates: a
  fix we already picked up via an early dev merge still appears as a new entry
  (when that happened, the changelog listed ~40% more news than we were
  actually missing). It understates: bullets group many commits under one line
  and silently drop the rest — in the v0.11.0 cycle it covered 394 of 659
  commits, including readable items it simply chose not to mention.
- **So the commit log is the source of truth for coverage, and the changelog
  for prose.** Bullets are resolved against our history by ancestry — because
  dev merges carry the identical commits (not cherry-picks),
  `git merge-base --is-ancestor` is exact. PR numbers are resolved to commits
  via upstream's convention of ending subjects with `(#N)`; where that breaks,
  the bullet is marked `NEW?` rather than guessed at. Commits no bullet cites
  are then listed directly, so nothing in the range is silently dropped.

The changelog is rebuilt on dev just before each release and merged to main by
the release merge, so the same mechanism works for both branches; only the
labels differ — beware, release tags v0.10.0 and later sit on main-side merge
commits that never enter dev's history, so `git describe` on `origin/dev`
claims v0.9.6 is the latest release. The script reports no release labels;
ask `git tag` directly if you need one.

Remaining imperfections: a `have` can rarely be wrong if a PR contains commits
that do not cite its number; bullets citing only issue links (`issues/N`,
unresolvable) are marked `NEW?`; and bare-`refac` commits that no bullet
mentions stay unexplained (counted, not read).
