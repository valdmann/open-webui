#!/usr/bin/env bash
# whatsnew.sh — answer "what's new upstream?" for this fork of open-webui.
#
# Usage: whatsnew.sh [<base> [<target>]]    (defaults: HEAD origin/main)
#
# Prints release-note bullets added upstream since <base>, each marked:
#   new    — cited commits are not in our history (genuinely new for us)
#   have   — already in our history, typically via an early origin/dev merge
#   new?   — cites nothing resolvable (or an unresolved PR); verify by hand
#
# Refs that do not resolve to a commit are rejected with an error. If
# CHANGELOG.md gained no bullet lines in the range, a note is printed instead
# of output (early dev merges carry commits but no release notes). Indented
# changelog sub-bullets are included. Deep replays are slow: every cited PR
# number is resolved by scanning the target's full subject list.
#
# Known limit: a bullet can rarely be marked "have" wrongly if a PR contains
# commits that do not cite the PR number in their subject. Treat "have" as a
# hint that reading the bullet is skippable, not as proof.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1

base=${1:-HEAD}
target=${2:-origin/main}

git fetch origin --tags --quiet || {
    echo "error: git fetch failed; refusing to report from stale refs" >&2
    exit 1
}

for r in "$base" "$target"; do
    if ! git rev-parse --verify --quiet "${r}^{commit}" >/dev/null; then
        echo "error: '$r' does not resolve to a commit (base and target must be commit-ish)" >&2
        exit 1
    fi
done

new_commits=$(git rev-list --count --no-merges "$base..$target")
last_release=$(git describe --tags --abbrev=0 "$target" 2>/dev/null || true)

echo "== $target (latest release: ${last_release:-none}) has $new_commits commit(s) not in $base's history"
if [ -n "$last_release" ] && [ "$(git rev-parse "${last_release}^{commit}")" != "$(git rev-parse "$target")" ]; then
    echo "== $target carries $(git rev-list --count --no-merges "$last_release..$target") unreleased commit(s) beyond $last_release"
fi
[ "$new_commits" = 0 ] && { echo "== nothing new"; exit 0; }

# subjects of all non-merge commits on target, once — PR resolution reuses this
subj_log=$(git log --no-merges --format='%H %s' "$target" 2>/dev/null)

verdict() { # $1 = changelog bullet text -> new | have | new?
    local miss=no unres=no resolved=no ref h n c found
    while read -r ref; do
        [ -z "$ref" ] && continue
        resolved=yes
        if [[ $ref == commit/* ]]; then
            h=${ref#commit/}
            git merge-base --is-ancestor "$h" "$base" 2>/dev/null || miss=yes
        else
            n=${ref#pull/}
            found=$(printf '%s\n' "$subj_log" | grep -E "\(#$n\)$" | cut -d' ' -f1)
            [ -z "$found" ] && unres=yes
            for c in $found; do
                git merge-base --is-ancestor "$c" "$base" || miss=yes
            done
        fi
    done < <(printf '%s\n' "$1" | grep -oE 'commit/[0-9a-f]{40}|pull/[0-9]+' | sort -u)
    [ "$miss" = yes ] && { echo new; return; }
    [ "$resolved" = yes ] && [ "$unres" = no ] && { echo have; return; }
    echo 'new?'
}

headline() { # the **bold** lead of a bullet, or the first 70 chars
    local h
    h=$(printf '%s\n' "$1" | grep -oE '\*\*[^*]+\*\*' | head -1 | tr -d '*' || true)
    echo "${h:-$(printf '%s\n' "$1" | cut -c1-70)}"
}

printed=no
while IFS= read -r raw; do
    printed=yes
    line=${raw#+}
    line=${line#"${line%%[![:space:]]*}"}
    case $line in
        '## '* | '### '* ) printf '\n%s\n' "$line" ;;
        '- '*)
            v=$(verdict "$line")
            case $v in
                new)    printf 'NEW  %s\n' "$line" ;;
                have)   printf 'have %s\n' "$(headline "$line")" ;;
                'new?') printf 'NEW? %s\n' "$line" ;;
            esac
            ;;
    esac
done < <(git diff "$base" "$target" -- CHANGELOG.md | grep -E '^\+ *(##|###|- )')
if [ "$printed" = no ]; then
    echo "== no release notes: CHANGELOG.md is unchanged in this range"
fi
exit 0