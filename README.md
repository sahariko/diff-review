# diff-review

A Claude Code plugin that turns a git diff into a page you can actually review, on a phone or on a desktop.

Terminal diffs are hard to read on a small screen, and most review tools need a mouse. `diff-review` builds one self-contained HTML page with:

- **A guide to the change.** A short plain-language summary, a "look closely" list ranked by risk with links that jump to the exact line, and a "safe to skim" list.
- **Before/after screenshots** when the diff changes how something looks.
- **The diff itself**: one column with wrapped lines on a phone, side by side on a wide screen, with collapsible files.
- **Navigation**: a sticky contents sidebar on wide screens (sections and files, with the current one highlighted), and a row of jump links on a phone.

<p align="center">
  <img src="docs/screenshots/phone-guide.png" width="260" alt="Phone: contents row, summary and risk-ranked list">
  <img src="docs/screenshots/phone-diff.png" width="260" alt="Phone: unified diff with wrapped lines">
</p>

![Desktop: guide and before/after screenshots](docs/screenshots/desktop-guide.png)

![Desktop: side-by-side diff](docs/screenshots/desktop-diff.png)

The screenshots come from [`examples/`](examples/), a small demo change. Open [`examples/brew-timer-review.html`](examples/brew-timer-review.html) in a browser to see the real page.

## Install

In Claude Code:

```
/plugin marketplace add sahariko/diff-review
/plugin install diff-review@diff-review
```

Restart Claude Code if it asks you to. To install by hand instead, copy `skills/diff-review/` into `~/.claude/skills/`.

### Requirements

| Needed for | What |
|---|---|
| The page | `git` and Python 3 |
| Before/after screenshots | Node 18+ and [Playwright](https://playwright.dev) with Chromium. If the repo doesn't have it, the skill tells you and suggests `npm i --no-save playwright && npx playwright install chromium` (about 150 MB). Without it, the page is built without screenshots. |
| Remote mode | A Claude Code setup that has the Artifact tool (publishes a private page you can open on any device) |

## Use

In any git repository, ask Claude Code:

```
/diff-review
/diff-review review the last 3 commits on my phone
/diff-review main..HEAD, local
```

Claude reads the diff, writes the review notes from the real code, takes screenshots if the UI changed, builds the page and opens it.

### Local and remote

| | Local | Remote |
|---|---|---|
| For | Reviewing at your computer | Reviewing on your phone, or sharing a link |
| What happens | Writes `~/.cache/diff-review/<repo>-<range>.html` and opens it in your browser | Publishes the same page as a private Artifact and opens the link |
| Your code | Stays on your machine | Is uploaded to a private page on claude.ai; only you can open it until you share it |

If the mode isn't clear, the skill uses local and offers remote. It never publishes unless you ask for a phone view, a link or sharing. A phone can't open a local file, so for the phone, use remote.

### Screenshots

For diffs that touch visible UI, the skill runs a preflight check and picks a source:

1. **Storybook**, if the repo has it: it screenshots the stories for the changed components.
2. **A dev server**, if the repo has a `dev` script: it opens the page that shows the change.
3. **Neither works**: it skips screenshots and says so. It never uses placeholder images.

The "before" image comes from a temporary git worktree of the base commit, removed afterwards.

## How it works

```
skills/diff-review/
  SKILL.md              the instructions Claude follows
  scripts/
    render_diff.py      git diff + notes.json + screenshots -> one HTML page
    diff.css, diff.js   the page's styles (light and dark) and its small script
    preflight.sh        what the repo offers for screenshots
    shoot.cjs           one Playwright screenshot of a URL or element
    base-worktree.sh    check out the "before" commit, clean up afterwards
    open.sh             open a file in the default browser (WSL, Linux, macOS)
```

The review notes are JSON that Claude writes after reading the diff:

```json
{
  "summary": ["What changed and why."],
  "focus": [{"path": "app.js", "line": 8, "title": "Clamp replaces the unchecked add",
             "why": "What could be wrong and what to check.", "risk": "medium"}],
  "skim": ["Mechanical changes the reader can skip."]
}
```

`render_diff.py` can also be run on its own: `python3 skills/diff-review/scripts/render_diff.py --repo . --range HEAD~1..HEAD --out review.html --standalone`.

## Limits

- Read-only. Feedback goes back through the chat.
- A snapshot, not a live view. Run it again after new commits.
- The guide is Claude's judgment. It points at where to look; it doesn't replace reading the code.
- Binary files show as "binary file". Diffs use 4 lines of context.
- Uncommitted work works through `git stash create`; tracked files only.

## Development

```
bash tests/smoke.sh
```

builds a throwaway repo, renders a page and checks the output, including that a focus link to a file outside the diff fails loudly.

## License

MIT
