#!/usr/bin/env bash
# Print the default review range: the whole branch since it left the default branch.
# On the default branch itself (or with no default branch found), print the last commit.
# usage: bash default-range.sh   (run inside the repo)
set -u
base=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
if [ -z "$base" ]; then
  for b in main master trunk develop; do
    git show-ref -q --verify "refs/heads/$b" && base=$b && break
  done
fi
head=$(git rev-parse HEAD)
if [ -n "$base" ] && [ "$(git rev-parse --abbrev-ref HEAD)" != "$base" ]; then
  mb=$(git merge-base "$base" HEAD 2>/dev/null || true)
  if [ -n "$mb" ] && [ "$mb" != "$head" ]; then echo "$mb..HEAD"; exit 0; fi
fi
if git rev-parse -q --verify HEAD~1 >/dev/null; then echo "HEAD~1..HEAD"
else echo "4b825dc642cb6eb9a060e54bf8d69288fbee4904..HEAD"; fi   # root commit: diff against the empty tree
