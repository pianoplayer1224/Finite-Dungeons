#!/usr/bin/env bash
# Parity check: replays tests/parity/scenarios.json + fuzz.json through ../pc/FiniteDungeons.py
# (the spec) and through the GDScript port, then diffs the canonical records.
# Prints "PARITY OK" and exits 0, or prints the first differences and exits 1.
#   GODOT=/path/to/godot ./tests/parity/run_parity.sh
#   SKIP_IMPORT=1 ...   skip the class-cache refresh (faster when no class_name changed)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-/home/ray/Documents/Godot/Godot_v4.7.1-stable_linux.x86_64}"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

if ! python3 -I "$ROOT/tests/parity/parity.py" "$OUT/py.txt" 2>"$OUT/py.err"; then
	grep -v "color: command not found" "$OUT/py.err"
	echo "Python side failed"
	exit 2
fi

# -s scripts resolve class_name globals from the editor's class cache; --import refreshes it
# so new or renamed core classes are visible without opening the editor.
if [ -z "${SKIP_IMPORT:-}" ]; then
	"$GODOT" --headless --path "$ROOT" --import >"$OUT/import.log" 2>&1
fi

"$GODOT" --headless --path "$ROOT" -s "$ROOT/tests/parity/parity.gd" -- "$OUT/gd.txt" >"$OUT/gd.log" 2>&1
# project.godot autoloads the godot_ai addon's helper, but addons/ is local-only (gitignored):
# without it Godot logs three harmless "addons/godot_ai/..." errors, which are not the port's.
grep -v "addons/godot_ai" "$OUT/gd.log" >"$OUT/gd.check.log"
if grep -qE "SCRIPT ERROR|Parse Error|ERROR:" "$OUT/gd.check.log" || [ ! -s "$OUT/gd.txt" ]; then
	grep -E -A3 "SCRIPT ERROR|Parse Error|ERROR:" "$OUT/gd.check.log" | head -40
	echo "GDScript side failed"
	exit 2
fi

if diff -u "$OUT/py.txt" "$OUT/gd.txt" >"$OUT/diff.txt"; then
	echo "PARITY OK ($(wc -l <"$OUT/py.txt") records)"
	exit 0
fi
head -80 "$OUT/diff.txt"
echo "... $(grep -c '^[-+][^-+]' "$OUT/diff.txt") differing lines"
exit 1
