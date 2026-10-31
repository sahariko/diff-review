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
# .diff-review.json: repo-level collapse/expand globs, no --notes needed; notes add to them; expand wins
mkdir e2e && printf 'e\n' > e2e/a.spec.ts && printf 'e\n' > e2e/helper.ts && printf 'g\n' > gen.out && printf 'o\n' > other.txt
git add -A && git commit -qm "cfg files"
quiet_of() { python3 -c 'import re,sys; h=open(sys.argv[1]).read(); print(re.search(r"data-quiet=\"(\d)\"[^>]*>\s*<summary>(?:(?!</summary>).)*?<b>"+re.escape(sys.argv[2])+"<", h, re.S).group(1))' "$1" "$2"; }
printf '{"collapse":["e2e/**","*.out"]}' > .diff-review.json
python3 "$render" --repo . --range HEAD~1..HEAD --out cfg.html
[ "$(quiet_of cfg.html helper.ts)" = 1 ] && [ "$(quiet_of cfg.html gen.out)" = 1 ] && [ "$(quiet_of cfg.html other.txt)" = 0 ]
printf '{"collapse":["other.txt"],"expand":["e2e/helper.ts"]}' > cn.json
python3 "$render" --repo . --range HEAD~1..HEAD --out cfg2.html --notes cn.json
[ "$(quiet_of cfg2.html other.txt)" = 1 ] && [ "$(quiet_of cfg2.html helper.ts)" = 0 ] && [ "$(quiet_of cfg2.html gen.out)" = 1 ]
printf '{bad' > .diff-review.json
if python3 "$render" --repo . --range HEAD~1..HEAD --out cfg3.html 2>err.txt; then echo "FAIL: bad .diff-review.json accepted"; exit 1; fi
grep -q '.diff-review.json' err.txt
rm .diff-review.json cn.json
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
# serve.sh: the server answers inside `run`, the job's status passes through, nothing is left listening
serve="$here/skills/diff-review/scripts/serve.sh"
set +e
bash "$serve" run --cmd "python3 -m http.server {port}" -- bash -c 'curl -sf "$SERVER_URL/" >/dev/null && echo "$SERVER_URL" > url.txt; exit 7'
[ "$?" -eq 7 ] || { echo "FAIL: serve.sh run did not return the job status"; exit 1; }
set -e
[ -s url.txt ]                                                   # the job reached the server
! curl -s -o /dev/null --max-time 2 "$(cat url.txt)"             # and it is gone afterwards
out=$(bash "$serve" start --cmd "python3 -m http.server {port}" --watch-pid $$)
curl -sf "$(echo "$out" | sed -n 's/^SERVER_URL=//p')/" >/dev/null
bash "$serve" stop "$(echo "$out" | sed -n 's/^SERVER_PID=//p')"
sleep 1
! curl -s -o /dev/null --max-time 2 "$(echo "$out" | sed -n 's/^SERVER_URL=//p')"
echo "ok"
