# Before/after screenshots

For diffs that touch visible UI, the skill captures a before and an after image and shows them in a "Visual changes" section. Phones get Before/After tabs; wide screens show both side by side.

## Tools

Run from the repo root.

| Script | Use |
|---|---|
| `scripts/preflight.sh` | Reports the package manager, Storybook, dev script, Playwright, Chromium and busy ports. |
| `scripts/shoot.cjs` | One screenshot of a URL or element. `--url --out [--width 390 --height 780 --wait ms --click role:button:Name --click css:.x --selector CSS --full --scheme dark\|light]` |
| `scripts/base-worktree.sh` | `<repo> <base> <dir>` checks out the before commit with `node_modules` linked and `.env` copied; `--remove <repo> <dir>` cleans up. |

`shoot.cjs` uses the repo's own Playwright. If there isn't one:

```
npm i --no-save playwright
npx playwright install chromium
```

That downloads about 150 MB. The skill asks before doing it.

## Where the images come from

1. **Storybook**, if the repo has it. Stories for the changed components are captured at `http://localhost:<port>/iframe.html?id=<story-id>&viewMode=story`. Ids are listed at `/index.json`.
2. **A dev server**, if the repo has a `dev` script. The skill opens the route that shows the change.
3. **Neither works** (no UI runner, needs credentials, won't start). The page is built without screenshots, and the skill says why.

## The before image

A temporary worktree of the base commit is created, the same source is started from it, and the worktree is removed afterwards. A new view has no before image; that side shows "none".

## File names

`<label>.before.png` and `<label>.after.png`, with hyphens in the label (`task-card-done`). Keep each file under about 400 KB.

## Pitfalls

- Another worktree may already hold Storybook's default port and serve stale stories. Start your own on a free port and check the story id is in its index.
- A story that ends with a play function can finish on an empty screen (for example a dialog that closes itself). Open an earlier story and use `--click` to reach the state you want.
- `--click role:button:Plant` matches the exact accessible name, so "Water the plants" is not a match.
