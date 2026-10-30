#!/usr/bin/env bash
# Report what this repo offers for screenshots. Run from the repo root.
# usage: bash preflight.sh
set -u
echo "repo: $PWD"
[ -f package.json ] || { echo "no package.json: no UI runner to screenshot; skip screenshots"; exit 0; }

pm=npm; [ -f pnpm-lock.yaml ] && pm=pnpm; [ -f yarn.lock ] && pm=yarn; [ -f bun.lockb ] || [ -f bun.lock ] && pm=bun
echo "package manager: $pm"

if [ -d .storybook ] || grep -q '"storybook"' package.json; then
  echo "storybook: yes (script: $(node -p "(require('./package.json').scripts||{}).storybook||'none'"))"
else
  echo "storybook: no"
fi
echo "dev script: $(node -p "(require('./package.json').scripts||{}).dev||'none'")"
[ -d node_modules ] && echo "node_modules: installed" || echo "node_modules: MISSING (run $pm install before starting anything)"

if node -e "require(require('module').createRequire(process.cwd()+'/x.js').resolve('playwright'))" 2>/dev/null \
   || ls node_modules/.pnpm 2>/dev/null | grep -q '^playwright@'; then
  echo "playwright: found in repo"
else
  echo "playwright: not in repo (use: npm i --no-save playwright, then npx playwright install chromium)"
fi
if ls ~/.cache/ms-playwright 2>/dev/null | grep -q chromium; then
  echo "chromium: installed"
else
  echo "chromium: missing (npx playwright install chromium)"
fi

for p in 6006 6007 3000 3001 5173; do
  curl -s -o /dev/null --max-time 1 "http://localhost:$p" && echo "port $p: IN USE (may be a stale server)" || true
done
