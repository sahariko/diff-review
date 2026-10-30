# How it works

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
    default-range.sh    the default range to review
```

## The flow

1. Pick the range: the whole branch since it left the default branch (`scripts/default-range.sh`), or the last commit when you are on the default branch.
2. Claude reads the diff and writes `notes.json` ([format](review-notes.md)).
3. If the diff changes how something looks, it captures before/after images ([how](ui-screenshots.md)).
4. `render_diff.py` builds one HTML page from the diff, the notes and the images.
5. Local mode opens the file; remote mode publishes a private Artifact.

## Running the renderer yourself

```
python3 skills/diff-review/scripts/render_diff.py \
  --repo . --range HEAD~1..HEAD --out review.html \
  --notes notes.json --shots shots/ --standalone
```

| Flag | |
|---|---|
| `--repo` | The git repository |
| `--range` | `BASE..HEAD`. The page embeds three scopes behind a selector: Branch (everything since `BASE`, committed or not: `git diff BASE`, when the range ends in `HEAD`), Committed (the range only) and Uncommitted (`git diff HEAD`) |
| `--out` | Output HTML file |
| `--notes` | Review notes JSON (optional) |
| `--shots` | Folder of `<label>.before.png` and `<label>.after.png` (optional) |
| `--standalone` | Wrap in a full HTML document, for opening as a local file. Leave it off when publishing as an Artifact. |

## The page

- Light and dark themes follow the system setting.
- Under 900px: one column, unified diffs, jump links and a back-to-top button.
- 900px and wider: side-by-side diffs and a sticky contents sidebar.
- Test files, `package.json`, READMEs and lockfiles start collapsed; a checkbox opens them.
