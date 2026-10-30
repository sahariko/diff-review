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
