#!/usr/bin/env bash
# Parse every tracked QML/JS, shell and Python file and fail on syntax errors.
# Only syntax is checked: qs.* and Quickshell imports cannot be resolved outside
# a running Quickshell, so qmllint's other warnings are noise here.
#
# Usage: tests/check-syntax.sh   (QMLLINT=/path/to/qmllint to override)
set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 1

qmllint=${QMLLINT:-$(command -v qmllint-qt6 || command -v qmllint || echo /usr/lib64/qt6/bin/qmllint)}
if [ ! -x "$qmllint" ]; then
    echo "qmllint not found; set QMLLINT" >&2
    exit 1
fi

failed=0
report=$(mktemp)
trap 'rm -f "$report"' EXIT

# QML and JS. qmllint exits non-zero on any warning, so read its JSON instead.
git ls-files -z '*.qml' '*.js' '*.mjs' | xargs -0 "$qmllint" --json "$report" >/dev/null 2>&1
python3 - "$report" <<'EOF' || failed=1
import json, sys
errors = 0
for f in json.load(open(sys.argv[1]))["files"]:
    for w in f.get("warnings", []):
        if w.get("id") == "syntax":
            errors += 1
            print(f'{f["filename"]}:{w.get("line", 0)}:{w.get("column", 0)}: {w["message"]}')
sys.exit(1 if errors else 0)
EOF

# Shell
while IFS= read -r -d '' f; do
    bash -n "$f" || failed=1
done < <(git ls-files -z '*.sh')

# Python
git ls-files -z '*.py' | python3 -c '
import ast, sys
bad = 0
for f in sys.stdin.read().split("\0"):
    if not f:
        continue
    try:
        ast.parse(open(f, "rb").read(), f)
    except SyntaxError as e:
        bad = 1
        print(f"{f}:{e.lineno}:{e.offset}: {e.msg}")
sys.exit(bad)
' || failed=1

if [ "$failed" -ne 0 ]; then
    echo "syntax check failed" >&2
    exit 1
fi
echo "syntax check passed"
