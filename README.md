# diff-review

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-d97757.svg)](#quickstart)

Review a git diff as a readable page, on your phone or your desktop. Claude tells you what changed and where to look, shows before/after screenshots for UI changes, and lays out the diff so it's pleasant to read.

![A review page with a contents sidebar, a summary, risk-ranked things to look at, and before/after screenshots](docs/screenshots/desktop-guide.png)

## Why

Terminal diffs are hard to read on a small screen, and most review tools need a mouse. You also still have to work out what matters in a 500-line diff.

`diff-review` reads the change for you and builds one self-contained HTML page:

- **A guide to the change.** A short summary, a "look closely" list ranked by risk that jumps to the exact line, and a "safe to skim" list.
- **Before/after screenshots** when the diff changes how something looks (Storybook or a dev server).
- **A diff built for reading.** Wrapped lines in one column on a phone, side by side on a wide screen, collapsible files, light and dark themes.
- **Easy navigation.** A sticky contents sidebar on desktop, jump links and a back-to-top button on a phone.

| On a phone: the guide | On a phone: the diff |
|---|---|
| ![Summary and things to look at](docs/screenshots/phone-guide.png) | ![Unified diff with wrapped lines](docs/screenshots/phone-diff.png) |

## Quickstart

### 1. Install

```
/plugin marketplace add sahariko/diff-review
/plugin install diff-review@diff-review
```

Without the plugin system, copy `skills/diff-review/` into `~/.claude/skills/`.

### 2. Run it in any git repo

```
/diff-review
```

Claude reads the diff, writes the review notes from the real code, takes screenshots if the UI changed, builds the page and opens it.

More examples:

```
/diff-review review the last 3 commits on my phone
/diff-review main..HEAD, local
```

## Local and remote

| | Local | Remote |
|---|---|---|
| For | Reviewing at your computer | Reviewing on your phone, or sharing a link |
| What happens | Writes `~/.cache/diff-review/<repo>-<range>.html` and opens it in your browser | Publishes the same page as a private Artifact and opens the link |
| Your code | Stays on your machine | Is uploaded to a private page on claude.ai; only you can open it until you share it |

If the mode isn't clear, it uses local and offers remote. It never publishes unless you ask for a phone view, a link or sharing. A phone can't open a local file, so for the phone, use remote.

![Side-by-side diff on desktop, with the file list in the sidebar](docs/screenshots/desktop-diff.png)

Want to see a real page? Open [`examples/brew-timer-review.html`](examples/brew-timer-review.html) in a browser.

## Screenshots of UI changes

For diffs that touch visible UI, a preflight check picks the source:

1. **Storybook**, if the repo has it: screenshots the stories for the changed components.
2. **A dev server**, if the repo has a `dev` script: opens the page that shows the change.
3. **Neither works**: skips screenshots and says so. It never uses placeholder images.

The "before" image comes from a temporary git worktree of the base commit, removed afterwards.

## Requirements

| For | You need |
|---|---|
| The page | `git` and Python 3 |
| Screenshots | Node 18+ and [Playwright](https://playwright.dev) with Chromium. If the repo doesn't have it, the skill asks before running `npm i --no-save playwright && npx playwright install chromium` (about 150 MB). Without it, the page is built without screenshots. |
| Remote mode | A Claude Code setup with the Artifact tool |

## How it works

```
skills/diff-review/
  SKILL.md              the instructions Claude follows
  scripts/
    render_diff.py      git diff + notes.json + screenshots -> one HTML page
    diff.css, diff.js   the page's styles (light and dark) and small script
    preflight.sh        what the repo offers for screenshots
    shoot.cjs           one Playwright screenshot of a URL or element
    base-worktree.sh    check out the "before" commit, clean up afterwards
    open.sh             open a file in the default browser (WSL, Linux, macOS)
```

Claude writes the review notes as JSON after reading the diff:

```json
{
  "summary": ["What changed and why."],
  "focus": [{"path": "app.js", "line": 8, "title": "Clamp replaces the unchecked add",
             "why": "What could be wrong and what to check.", "risk": "medium"}],
  "skim": ["Mechanical changes the reader can skip."]
}
```

`render_diff.py` also runs on its own:

```
python3 skills/diff-review/scripts/render_diff.py --repo . --range HEAD~1..HEAD --out review.html --standalone
```

## Limits

- Read-only. Feedback goes back through the chat.
- A snapshot, not a live view. Run it again after new commits.
- The guide is Claude's judgment. It points at where to look; it doesn't replace reading the code.
- Binary files show as "binary file". Diffs use 4 lines of context.
- Uncommitted work goes through `git stash create`, so tracked files only.

## Development

```
bash tests/smoke.sh
```

Builds a throwaway repo, renders a page and checks the output, including that a focus link to a file outside the diff fails loudly.

## License

[MIT](LICENSE)
