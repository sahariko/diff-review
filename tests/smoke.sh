#!/usr/bin/env bash
# Builds a throwaway repo, renders a review page from it, and checks the output.
# usage: bash tests/smoke.sh
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
render="$here/skills/diff-review/scripts/render_diff.py"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q -b main && git config user.name t && git config user.email t@example.com
printf 'one\ntwo\n' > a.txt && git add -A && git commit -qm "first"
printf 'one\nTWO\nthree\n' > a.txt && git commit -qam "second change"
printf '{"summary":["s"],"focus":[{"path":"a.txt","line":2,"title":"t","why":"w","risk":"high"}],"skim":["k"]}' > notes.json
python3 "$render" --repo . --range HEAD~1..HEAD --out out.html --notes notes.json --standalone
grep -q '<!doctype html>' out.html
grep -q 'data-target="f0-L2"' out.html   # focus link resolves to an added line
grep -q 'class="toc"' out.html
grep -q '<span class="branch">main</span>' out.html   # branch shown at the top
grep -q '<title>[^<]* · main</title>' out.html   # tab title: repo · branch
git checkout -q --detach && python3 "$render" --repo . --range HEAD~1..HEAD --out det.html --standalone
grep -qE '<span class="branch">[0-9a-f]{7,}</span>' det.html   # detached HEAD shows the short sha
git checkout -q main
# scopes: Branch is the default and holds everything; Committed and Uncommitted split it
grep -q 'class="layout" data-scope="branch"' out.html
grep -q 'No uncommitted changes' out.html   # empty state
printf 'one\nTWO\nthree\nSTAGED\n' > a.txt && git add a.txt && printf 'one\nTWO\nthree\nSTAGED\nWORK\n' > a.txt
python3 "$render" --repo . --range HEAD~1..HEAD --out scopes.html --standalone
python3 - scopes.html <<'PY'
import re, sys
h = open(sys.argv[1]).read()
def scope(pre):
    return re.search(r'id="%s0".*?</details>' % pre, h, re.S).group(0)
branch, committed, uncommitted = scope("f"), scope("c"), scope("u")
assert "TWO" in branch and "STAGED" in branch and "WORK" in branch       # branch: commit + staged + unstaged
assert "TWO" in committed and "STAGED" not in committed and "WORK" not in committed   # committed: the range only
assert "STAGED" in uncommitted and "WORK" in uncommitted                  # uncommitted: staged + unstaged
assert "No committed changes" not in h and "No uncommitted changes" not in h
PY
git reset -q --hard HEAD
# a focus item pointing outside the diff must fail loudly
printf '{"focus":[{"path":"nope.txt","title":"t","why":"w"}]}' > bad.json
if python3 "$render" --repo . --range HEAD~1..HEAD --out bad.html --notes bad.json 2>/dev/null; then
  echo "FAIL: unknown focus path was accepted"; exit 1; fi
bash "$here/skills/diff-review/scripts/preflight.sh" >/dev/null
# default range: whole branch off main, last commit on main
dr="$here/skills/diff-review/scripts/default-range.sh"
[ "$(bash "$dr")" = "HEAD~1..HEAD" ]                       # on main
git checkout -q -b feature && printf 'x\n' > b.txt && git add -A && git commit -qm "b" && printf 'y\n' >> b.txt && git commit -qam "c"
[ "$(bash "$dr")" = "$(git rev-parse main)..HEAD" ]        # on a branch: from the merge-base
# titles: never a stash subject or "and N more"; humanised branch, explicit override, capped length
title_for() {
  python3 "$render" --repo . --out title.html "$@" >/dev/null
  python3 -c 'import re,sys; print(re.search(r"<h1[^>]*>(.*?)</h1>", open(sys.argv[1]).read()).group(1))' title.html
}
absent() { if grep -qE "$1" title.html; then echo "FAIL: found $1"; exit 1; fi; }
git checkout -q -b fix/make_titles-short
printf 'p\n' > c.txt && git add -A && git commit -qm "c one" && printf 'q\n' >> c.txt && git commit -qam "c two"
[ "$(title_for --range main..HEAD)" = "Make titles short" ]
absent ' more</h1>'
[ "$(title_for --range main..HEAD --title 'Explicit title')" = "Explicit title" ]
[ "$(title_for --range HEAD~1..HEAD)" = "c two" ]           # one commit: its subject
[ "$(title_for --range main..HEAD~1)" = "3 commits" ]       # a bare revision has no name to use
git checkout -q -b develop
[ "$(title_for --range main..HEAD)" = "4 commits" ]         # neither does a trunk branch
git checkout -q fix/make_titles-short
printf 'stashed\n' >> c.txt; wip=$(git stash create); git checkout -q -- c.txt
[ "$(title_for --range "main..$wip")" = "Make titles short" ]    # commits plus a stash: the branch
absent 'WIP on|index on'
grep -q '4 commits' title.html                                   # the stash commits are not counted
[ "$(title_for --range "HEAD..$wip")" = "Uncommitted changes" ]  # only a stash
absent 'WIP on|index on'
git commit -q --allow-empty -m "WIP on the parser"               # a real commit that starts with WIP
[ "$(title_for --range HEAD~1..HEAD)" = "WIP on the parser" ]
t=$(title_for --range main..HEAD --title "$(printf 'word %.0s' $(seq 1 40))")
[ "${#t}" -le 82 ]                                               # 80 characters, 82 bytes in a C locale
case "$t" in *"word…") ;; *) echo "FAIL: not cut at a word: $t"; exit 1 ;; esac
grep -q '<h1 title="word word' title.html                        # the full text stays reachable
echo "ok"
