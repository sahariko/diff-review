#!/usr/bin/env python3
"""Render a git range as one self-contained HTML review page (phone and desktop).

usage: render_diff.py --repo DIR --range BASE..HEAD --out FILE [--notes notes.json] [--shots DIR] [--standalone]

notes.json (all keys optional):
  {"summary": ["paragraph", ...],
   "focus":   [{"path": "src/x.ts", "line": 40, "title": "short", "why": "one or two sentences",
                "risk": "high|medium|low"}],
   "skim":    ["what is mechanical and safe to skim", ...]}

shots DIR holds <label>.before.png and/or <label>.after.png (png/jpg/webp).
"""
import argparse
import base64
import html
import json
import os
import re
import subprocess
import sys

ap = argparse.ArgumentParser()
ap.add_argument("--repo", required=True)
ap.add_argument("--range", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--notes")
ap.add_argument("--shots")
ap.add_argument("--standalone", action="store_true", help="wrap in a full HTML document (local files); omit for Artifact publishing")
args = ap.parse_args()
e = html.escape


def git(*a):
    return subprocess.run(["git", "-C", args.repo, *a], capture_output=True, text=True, check=True).stdout


# ---- git data -------------------------------------------------------------
head = args.range.split("..")[-1]
log = git("log", "--format=%h\x1f%s\x1f%an\x1f%ad", "--date=short", args.range).strip().split("\n")
commits = [l.split("\x1f") for l in log if l]
single = len(commits) == 1
raw = git("diff", "-U4", "--no-color", args.range)

files, cur = [], None
for line in raw.split("\n"):
    if line.startswith("diff --git "):
        m = re.match(r"diff --git a/(.*) b/(.*)", line)
        cur = {"path": m.group(2), "hunks": [], "add": 0, "del": 0, "status": "modified", "binary": False}
        files.append(cur)
    elif cur is None:
        continue
    elif line.startswith("new file"):
        cur["status"] = "added"
    elif line.startswith("deleted file"):
        cur["status"] = "deleted"
    elif line.startswith("Binary files"):
        cur["binary"] = True
    elif line.startswith("@@"):
        m = re.match(r"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@ ?(.*)", line)
        cur["hunks"].append({"old": int(m.group(1)), "new": int(m.group(2)), "ctx": m.group(3), "lines": []})
    elif cur["hunks"] and line[:1] in ("+", "-", " "):
        cur["hunks"][-1]["lines"].append(line)
        if line[0] == "+":
            cur["add"] += 1
        elif line[0] == "-":
            cur["del"] += 1

total_add = sum(f["add"] for f in files)
total_del = sum(f["del"] for f in files)
file_index = {f["path"]: i for i, f in enumerate(files)}

# ---- diff rendering -------------------------------------------------------
def cell(cls, num, text, anchor=""):
    a = f' data-a="{anchor}"' if anchor else ""
    return f'<div class="c {cls}"{a}><span class="num">{num}</span><code>{e(text) or " "}</code></div>'


def rows_for(fi, h):
    """Yield (old_cell, new_cell, unified_cell) tuples for one hunk."""
    o, n = h["old"], h["new"]
    out, dels, adds = [], [], []

    def flush():
        for k in range(max(len(dels), len(adds))):
            d = dels[k] if k < len(dels) else None
            a = adds[k] if k < len(adds) else None
            left = cell("del", d[0], d[1]) if d else cell("empty", "", "")
            right = cell("add", a[0], a[1], f"f{fi}-L{a[0]}") if a else cell("empty", "", "")
            out.append((left, right))
        dels.clear()
        adds.clear()

    uni = []
    for ln in h["lines"]:
        kind, text = ln[0], ln[1:]
        if kind == "-":
            dels.append((o, text))
            uni.append(f'<div class="u del"><span class="num">{o}</span><span class="mark">−</span><code>{e(text) or " "}</code></div>')
            o += 1
        elif kind == "+":
            adds.append((n, text))
            uni.append(f'<div class="u add" data-a="f{fi}-L{n}"><span class="num">{n}</span><span class="mark">+</span><code>{e(text) or " "}</code></div>')
            n += 1
        else:
            flush()
            out.append((cell("ctx", o, text), cell("ctx", n, text, f"f{fi}-L{n}")))
            uni.append(f'<div class="u ctx" data-a="f{fi}-L{n}"><span class="num">{n}</span><span class="mark"></span><code>{e(text) or " "}</code></div>')
            o += 1
            n += 1
    flush()
    return out, uni


def render_file(i, f):
    quiet = "test" in f["path"].split("/")[-1] or f["path"].endswith(("package.json", "README.md", ".lock", "lock.yaml"))
    d, _, name = f["path"].rpartition("/")
    unified, split = [], []
    for h in f["hunks"]:
        pairs, uni = rows_for(i, h)
        head_row = f'<div class="hunk">@@ line {h["new"]} {e(h["ctx"])}</div>'
        unified.append(head_row + "".join(uni))
        split.append(head_row + "".join(f'<div class="pair">{l}{r}</div>' for l, r in pairs))
    body = "binary file" if f["binary"] and not f["hunks"] else (
        f'<div class="view-unified">{"".join(unified)}</div><div class="view-split">{"".join(split)}</div>')
    badge = f'<em class="st {f["status"]}">{f["status"]}</em>' if f["status"] != "modified" else ""
    return f"""<details class="file" id="f{i}" data-quiet="{int(quiet)}"{"" if quiet else " open"}>
<summary><span class="fname"><span class="dir">{e(d + "/") if d else ""}</span><b>{e(name)}</b>{badge}</span>
<span class="stat"><i class="a">+{f["add"]}</i> <i class="d">−{f["del"]}</i></span></summary>
<div class="code">{body}</div></details>"""


# ---- review notes ---------------------------------------------------------
notes = json.load(open(args.notes)) if args.notes else {}


def focus_html():
    items = []
    for k, fo in enumerate(notes.get("focus", [])):
        i = file_index.get(fo["path"])
        if i is None:
            sys.exit(f"focus path not in diff: {fo['path']}")
        risk = fo.get("risk", "medium")
        line = fo.get("line")
        target = f"f{i}-L{line}" if line else f"f{i}"
        where = f'{fo["path"].split("/")[-1]}{":" + str(line) if line else ""}'
        items.append(
            f'<li><a class="jump" href="#{target}" data-target="{target}">'
            f'<span class="risk {risk}">{risk}</span><b>{e(fo["title"])}</b>'
            f'<span class="where">{e(where)}</span></a><p>{e(fo["why"])}</p></li>')
    return "".join(items)


def notes_html():
    if not notes:
        return ""
    parts = ['<section class="guide" id="guide"><h2>What to know</h2>']
    parts += [f"<p>{e(p)}</p>" for p in notes.get("summary", [])]
    if notes.get("focus"):
        parts.append(f'<h3>Look closely</h3><ol class="focus">{focus_html()}</ol>')
    if notes.get("skim"):
        parts.append("<h3>Safe to skim</h3><ul>" + "".join(f"<li>{e(s)}</li>" for s in notes["skim"]) + "</ul>")
    parts.append("</section>")
    return "".join(parts)


# ---- screenshots ----------------------------------------------------------
def shots_html():
    if not args.shots or not os.path.isdir(args.shots):
        return ""
    labels = {}
    for fn in sorted(os.listdir(args.shots)):
        m = re.match(r"(.+)\.(before|after)\.(png|jpe?g|webp)$", fn)
        if m:
            labels.setdefault(m.group(1), {})[m.group(2)] = (fn, m.group(3).replace("jpg", "jpeg"))
    cards = []
    for label, sides in labels.items():
        figs = []
        for side in ("before", "after"):
            if side in sides:
                fn, ext = sides[side]
                b64 = base64.b64encode(open(os.path.join(args.shots, fn), "rb").read()).decode()
                figs.append(f'<figure data-side="{side}"><figcaption>{side}</figcaption>'
                            f'<img alt="{e(label)} {side}" src="data:image/{ext};base64,{b64}"></figure>')
            else:
                figs.append(f'<figure data-side="{side}"><figcaption>{side}</figcaption><div class="none">none</div></figure>')
        cards.append(f'<div class="shot" data-show="after"><h3>{e(label.replace("-", " "))}</h3>'
                     f'<div class="tabs"><button type="button" data-s="before">Before</button>'
                     f'<button type="button" data-s="after" aria-pressed="true">After</button></div>'
                     f'<div class="figs">{"".join(figs)}</div></div>')
    return f'<section class="visual" id="visual"><h2>Visual changes</h2>{"".join(cards)}</section>' if cards else ""


# ---- page -----------------------------------------------------------------
toc = "".join(
    f'<a href="#f{i}" data-target="f{i}"><span>{e(f["path"])}</span><span class="stat"><i class="a">+{f["add"]}</i> <i class="d">−{f["del"]}</i></span></a>'
    for i, f in enumerate(files))
sections = "\n".join(render_file(i, f) for i, f in enumerate(files))
if single:
    s, subj, au, dt = commits[0]
    title_html = f'<div class="sha">{e(s)} · {e(dt)} · {e(au)}</div><h1>{e(subj)}</h1>'
else:
    title_html = (f'<div class="sha">{e(args.range)} · {len(commits)} commits</div><h1>{e(commits[0][1])}'
                  f'{" and " + str(len(commits) - 1) + " more" if len(commits) > 1 else ""}</h1>')
    title_html += '<ul class="commits">' + "".join(f"<li><code>{e(c[0])}</code> {e(c[1])}</li>" for c in commits[:12]) + "</ul>"

guide_h, shots_h = notes_html(), shots_html()
sections_toc = ([("guide", "What to know")] if guide_h else []) + ([("visual", "Visual changes")] if shots_h else []) + [("files", f"Files ({len(files)})")]
toc_html = '<nav class="toc" aria-label="Contents">' + "".join(f'<a href="#{i}">{e(t)}</a>' for i, t in sections_toc) + "</nav>"

CSS = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "diff.css")).read()
JS = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "diff.js")).read()

page = f"""<title>Diff Review</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600&family=IBM+Plex+Sans:wght@400;600&display=swap">
<style>{CSS}</style>
<main>
<header>{title_html}
<div class="totals">{len(files)} files · <span class="a">+{total_add}</span> <span class="d">−{total_del}</span>
<label class="toggle"><input type="checkbox" id="quiet-toggle"> Open tests &amp; config</label></div></header>
{toc_html}
{guide_h}
{shots_h}
<section id="files"><h2>Files changed</h2><nav class="files" aria-label="Files">{toc}</nav></section>
{sections}
</main>
<script>{JS}</script>
"""
if args.standalone:
    page = ("<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">"
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
            "<style>:root{color-scheme:light}body{margin:0}img{max-width:100%}[hidden]{display:none!important}</style>"
            "</head><body>" + page + "</body></html>")
open(args.out, "w").write(page)
print(f"{len(files)} files, +{total_add} -{total_del}, {len(page) // 1024} KB -> {args.out}")
