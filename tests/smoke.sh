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
echo "ok"
