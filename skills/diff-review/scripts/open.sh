#!/usr/bin/env bash
# Open a local file in the default browser (WSL, Linux, macOS). usage: bash open.sh <file.html>
f=$(readlink -f "$1")
if command -v wslview >/dev/null; then wslview "$f"
elif command -v explorer.exe >/dev/null && command -v wslpath >/dev/null; then explorer.exe "$(wslpath -w "$f")" || true
elif command -v xdg-open >/dev/null; then xdg-open "$f" >/dev/null 2>&1 &
elif command -v open >/dev/null; then open "$f"
else echo "no opener found; open this file yourself: $f"; exit 1; fi
echo "opened $f"
