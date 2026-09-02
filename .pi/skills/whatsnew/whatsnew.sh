#!/usr/bin/env bash
# whatsnew.sh — answer "what's new upstream?" for this fork of open-webui.
#
# Usage: whatsnew.sh [<base> [<target>]]    (defaults: HEAD origin/main)
#
# Reports on every commit reachable from <target> but not <base>, in two parts:
#
#   1. Release-note bullets added upstream (the CHANGELOG.md diff), marked:
#        NEW   — cited commits are not in our history; genuinely new for us
#        have  — already in our history (typically via an early origin/dev
#                merge); only the headline is shown
#        NEW?  — cites nothing resolvable; shown in full but verify by hand
#   2. Every commit in the range that no bullet cites, listed by subject
#      under "== not mentioned in the changelog". The changelog is a curated
#      summary, not a ledger, so this completes its coverage with raw commit
#      subjects; uninformative subjects ("refac", "chore: format") are
#      aggregated to a count instead of listed.
#
# Works identically for origin/main (the release branch) and origin/dev
# (unreleased work): mid-cycle dev runs simply have no bullets yet, and the
# not-mentioned section is the whole answer. Refs that do not resolve to a
# commit are rejected with an error.
#
# Known limits: a bullet can rarely be marked "have" wrongly if a PR contains
# commits that do not cite the PR number in their subject; and commits the
# changelog leaves unexplained stay that way (bare "refac" noise is counted,
# not read). Deep replays are slow: every cited PR number is resolved by
# scanning the target's full subject list.
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
echo "== $target has $new_commits commit(s) not in $base's history"
[ "$new_commits" = 0 ] && { echo "== nothing new"; exit 0; }

# subjects of all non-merge commits on target, once — PR resolution reuses this
subj_log=$(git log --no-merges --format='%H %s' "$target" 2>/dev/null)

cited_file=$(mktemp)
trap 'rm -f "$cited_file"' EXIT

verdict() { # $1 = bullet -> prints new | have | new?; records cited hashes
    local miss=no unres=no resolved=no ref h n c found acc=''
    while read -r ref; do
        [ -z "$ref" ] && continue
        resolved=yes
        if [[ $ref == commit/* ]]; then
            h=${ref#commit/}
            acc+="$h"$'\n'
            git merge-base --is-ancestor "$h" "$base" 2>/dev/null || miss=yes
        else
            n=${ref#pull/}
            found=$(printf '%s\n' "$subj_log" | grep -E "\(#$n\)$" | cut -d' ' -f1)
            [ -z "$found" ] && unres=yes
            for c in $found; do
                acc+="$c"$'\n'
                git merge-base --is-ancestor "$c" "$base" || miss=yes
            done
        fi
    done < <(printf '%s\n' "$1" | grep -oE 'commit/[0-9a-f]{40}|pull/[0-9]+' | sort -u)
    [ -n "$acc" ] && printf '%s' "$acc" >> "$cited_file"
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
        -' '*)
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

# complete the changelog: commits in range that no bullet cites
sort -u -o "$cited_file" "$cited_file"
mapfile -t unmentioned < <(
    awk -F'|' -v c="$cited_file" '
        FILENAME == c { cited[$0]; next }
        !($1 in cited)
    ' "$cited_file" <(git log --no-merges --format='%H|%s' "$base..$target")
)
if [ "${#unmentioned[@]}" -gt 0 ]; then
    printf '\n== %d commit(s) not mentioned in the changelog:\n' "${#unmentioned[@]}"
    noise=0
    for e in "${unmentioned[@]}"; do
        s=${e#*|}
        case $s in
            refac | 'chore: format' ) noise=$((noise + 1)) ;;
            * ) printf '%s\n' "$s" ;;
        esac
    done
    [ "$noise" -gt 0 ] && printf '  + %d with bare subjects (refac, chore: format) — see git log %s..%s\n' \
        "$noise" "$base" "$target"
fi
exit 0
