---
name: diff-review
description: Use when the user wants to review code changes in a readable page instead of the terminal, on a phone or on desktop, asks for a visual diff, a review page or a summary of what to look at, or says /diff-review. Covers the latest commit, a commit range, a branch, or uncommitted work, in any git repo.
---

# Diff Review

Builds a self-contained HTML page for reviewing a git diff: a table of contents, a short guide to the change, before/after screenshots when the UI changed, and the diff itself. One column with unified diffs on a phone, side-by-side at 900px and wider.

Crit and Plannotator were tried for this and don't work on a phone (hover-only comment buttons, localhost-only server). This page is read-only; the user sends feedback in chat.

`<skill-dir>` is the "Base directory for this skill" shown when this skill loads. Scripts need Python 3 and git; screenshots also need Node 18+.

## Steps

1. **Pick the range.** Default is the whole branch: run `bash <skill-dir>/scripts/default-range.sh` in the repo (merge-base with the default branch to `HEAD`; the last commit when already on the default branch). If the user names a commit, a count ("last 3 commits") or a range, use that instead. Only uncommitted work: pass `HEAD..HEAD` and read the Uncommitted tab (`git add -N` new files first so they show). State the range you chose. For a range ending in `HEAD` the first scope tab shows everything since the base: the commits plus staged and unstaged edits (the diff of the base against the working tree).
2. **Read the diff yourself** (`git diff <range>`) before writing the notes. The guide is your judgment, so write it from the real code, including callers or validation outside the diff when a risk depends on them.
3. **Write `notes.json`** in the scratchpad (schema below).
4. **Screenshot gate (never skipped).** Run `git diff --name-only <range>` and check the list: if any file is a style (`.css`, `.scss`, `.sass`, `.less`, CSS-in-JS or theme/token files), a view component (`.tsx`, `.jsx`, `.vue`, `.svelte`), a template, or a story, the diff changes how something looks and you capture before/after screenshots as part of this task, without asking. Start with `preflight.sh`. If no file matches, write "no visual files in the diff" in the reply's Screenshots line. See Screenshots.
5. **Render** to the path for the mode (see Modes). Add `--standalone` in local mode so the file is a complete HTML document; omit it for remote:
   ```bash
   python3 <skill-dir>/scripts/render_diff.py \
     --repo "$PWD" --range HEAD~1..HEAD --out <out>.html \
     --notes <scratchpad>/notes.json [--shots <scratchpad>/shots] [--title "Short summary"]
   ```
   The title is the commit subject for one commit and the humanised branch name for several. Pass `--title` (a plain phrase, under 60 characters) when several commits sit on a branch whose name does not say what changed; 80 characters is the cap.
6. **Deliver** by mode, then **reply with the link or path and three lines**: the range, the one thing in the guide that most needs a human look, and `Screenshots:` with either the pairs captured or the blocker found (what preflight or the server start reported). "I haven't run the app", "to keep it quick" and "I can take them if you want" are not blockers.

## Modes

| | Local | Remote |
|---|---|---|
| Use when | The user is at the machine, or says local, private, or not to upload | The user wants it on a phone, wants a link, or wants to share it |
| Output | `~/.cache/diff-review/<repo>-<range>.html` with `--standalone` (create the folder; the file is self-contained) | Scratchpad `review.html` |
| Deliver | `bash <skill-dir>/scripts/open.sh <file>` opens it in the default browser | Publish with the Artifact tool, reusing the same `file_path` (or earlier `url`) per review so the link stays; `icon: "code"` on first publish; then Artifact `action: "open"` on the URL |
| Where the code goes | Stays on this machine | Uploaded to a private Artifact on claude.ai |
| Fonts | Falls back to system fonts offline | Google Fonts |

- If the mode is unclear, use **local** and offer remote in one line. Never publish without the user asking for a phone view, a link or sharing.
- Remote with no way to open a browser here: put the link first in the reply. Local with no opener found: print the file path.
- A phone cannot open a local file. If the user wants the phone view later, render again in remote mode.

## notes.json

```json
{
  "summary": ["What the change does and why, 1-2 short paragraphs.", "What was added around it (tests, config)."],
  "focus": [
    {"path": "src/db/completions.ts", "line": 116, "title": "Short noun phrase",
     "why": "One or two sentences: what could be wrong and what to check.", "risk": "high"}
  ],
  "skim": ["Mechanical changes the reader can skip."]
}
```

- `summary`: plain language, no restating filenames line by line. The reader should know the intent before opening any code.
- `focus`: 2-5 items, ordered by risk. `line` is the line number in the **new** file and must be an added or context line shown in the diff; omit it to link to the file. `path` must be in the diff or the script exits.
- `risk`: `high` (wrong answer, data loss, security), `medium` (fragile, hard to notice when broken), `low` (worth a glance).
- `skim`: only for changes you actually checked are mechanical.

Do not pad `focus` to look thorough. If nothing is risky, say so in `summary` and leave `focus` out.

## Screenshots

Required whenever the step 4 gate matches, including uncommitted work, small spacing or colour tweaks and refactors that restyle (the reviewer cannot judge CSS from the diff alone). Skipping needs a concrete blocker from the sources below, reported in the reply. The script embeds `<label>.before.png` and `<label>.after.png` from `--shots`. Either side may be missing for a new or removed view. Labels use hyphens (`task-card-done`). Phone width (about 390px) unless the change is desktop-only. Keep each PNG under about 400 KB; the page must stay under 16 MB.

Bundled tools (run from the repo root, with `bash` / `node`):

| Script | Use |
|---|---|
| `scripts/preflight.sh` | Reports package manager, Storybook, dev script, Playwright, Chromium, busy ports. Run it first. |
| `scripts/shoot.cjs` | One screenshot of a URL or element: `--url --out [--width 390 --height 780 --wait ms --click role:button:Name --click css:.x --selector CSS --full]`. Finds the repo's own Playwright. |
| `scripts/base-worktree.sh` | `<repo> <base> <dir>` checks out the before commit with `node_modules` linked and `.env` copied; `--remove <repo> <dir>` cleans up. |

If preflight shows Playwright or Chromium missing, install without touching the repo: `npm i --no-save playwright` then `npx playwright install chromium` (about 150 MB download; tell the user). If that is not possible, skip screenshots.

Pick the source by what preflight found:

1. **Storybook**: screenshot stories for the changed components at `http://localhost:<port>/iframe.html?id=<story-id>&viewMode=story`; ids come from `/index.json`. Start it on a free port with `--ci --no-open`. Other worktrees often hold 6006 with stale stories, so confirm the story id you want is in the index of the server you started. A story with a play function can end on an empty screen (a dialog that closes itself); open an earlier story and use `--click` to reach the state instead.
2. **No Storybook, but a dev server** (`dev` script, or a `run` skill if present): start it, open the route that shows the change, and capture with `shoot.cjs`. Try it before concluding it needs a database or login; skip only if the start or the page actually fails.
3. **Neither works** (you tried): skip screenshots and put the failure in the reply's Screenshots line. Never use a placeholder image.

For a **before** image, make a base worktree, start the same source from it, capture, then remove it. A new view has no before; leave that side out.

Stop every server you started, by PID. Never `pkill -f` a pattern: it can match your own shell or someone else's server.

## Page behavior

- A Contents row at the top links to What to know, Visual changes (when present) and Files.
- The page header has a scope selector: **Branch** (everything since the base: commits plus uncommitted edits), **Committed** (only the range) and **Uncommitted** (`git diff HEAD`, staged or not). All three diffs are rendered into the page, so switching needs no server. The notes and screenshots belong to the range and show only under Branch.
- Files open by default except tests and config (`test` in the name, `package.json`, README, lockfiles). The "Open tests & config" checkbox toggles them.
- Focus items jump to the line and flash it. Works in both unified and side-by-side views.
- Screenshots: Before/After tabs on a phone, both side by side on desktop.

## Limits

- Read-only. Comments go through chat; apply requested changes yourself, then re-render to the same URL.
- Renders a snapshot, not a live view. Re-run after new commits.
- Binary files show as "binary file". Diffs use 4 lines of context.
- Remote mode only: the artifact is private; others cannot open it until the user shares it from the page's Share menu.
