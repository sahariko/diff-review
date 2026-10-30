#!/usr/bin/env bash
# Check out the "before" commit beside the repo so its UI can be screenshotted.
# usage: bash base-worktree.sh <repo> <base-commit> <dir>      create, symlink node_modules
#        bash base-worktree.sh --remove <repo> <dir>            clean up
set -euo pipefail
if [ "$1" = "--remove" ]; then
  git -C "$2" worktree remove --force "$3"
  exit 0
fi
repo=$1; base=$2; dir=$3
git -C "$repo" worktree add --detach "$dir" "$base"
[ -d "$repo/node_modules" ] && ln -s "$repo/node_modules" "$dir/node_modules"
for f in .env .env.local; do [ -f "$repo/$f" ] && cp "$repo/$f" "$dir/$f"; done
echo "$dir ready at $(git -C "$dir" rev-parse --short HEAD)"
