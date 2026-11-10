#!/usr/bin/env bash
# Prints the CHANGELOG.md section for a version (heading "## 1.3.1 - 2026-11-10" or "## 1.3.1").
# Usage: scripts/release-notes.sh v1.3.1     Fails if there is no such section or it is empty.
set -euo pipefail
cd "$(dirname "$0")/.."
v="${1:?usage: release-notes.sh <version>}"
v="${v#v}"
notes=$(awk -v v="$v" '
	BEGIN { head = "## " v }
	index($0, head) == 1 && (length($0) == length(head) || substr($0, length(head) + 1, 1) == " ") { found = 1; next }
	/^## / && found { exit }
	found { print }
' CHANGELOG.md)
# trim blank lines at both ends
notes=$(printf '%s\n' "$notes" | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}')
[ -n "$notes" ] || { echo "no CHANGELOG.md entry for $v" >&2; exit 1; }
printf '%s\n' "$notes"
