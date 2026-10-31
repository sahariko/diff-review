# Review notes format

Claude writes this JSON after reading the diff. `render_diff.py` turns it into the "What to know" section.

```json
{
  "summary": ["What changed and why.", "What was added around it."],
  "focus": [
    {
      "path": "app.js",
      "line": 8,
      "title": "Clamp replaces the unchecked add",
      "why": "What could be wrong and what to check.",
      "risk": "medium"
    }
  ],
  "skim": ["Mechanical changes the reader can skip."],
  "collapse": ["e2e/**", "**/*.stories.tsx"],
  "expand": ["src/test-utils/**"]
}
```

| Key | Meaning |
|---|---|
| `summary` | One or two short paragraphs in plain language. The reader should know the intent before opening any code. |
| `focus` | Two to five items, most risky first. `path` must be in the diff or the renderer exits with an error. `line` is a line number in the **new** file that appears in the diff; leave it out to link to the file. |
| `risk` | `high` (wrong answer, data loss, security), `medium` (fragile, hard to notice when broken) or `low` (worth a glance). |
| `skim` | Changes that were checked and are mechanical. |
| `collapse` | Path globs (`**` crosses folders) to fold by default, taken from the project's test, e2e and story config. Adds to the built-in name guesses. |
| `expand` | Path globs to keep open even if a guess or `collapse` would fold them. |

Every key is optional. With no notes, the page has just the contents, screenshots and diff.

See [`examples/notes.json`](../examples/notes.json).
