#!/usr/bin/env bash
# Builds dist/Kibble-v<version>.zip (with a top-level Kibble/ folder) from the committed files.
# The list of addon files is read from Kibble.toc, so a new Lua file can't be forgotten.
# Usage: scripts/package.sh [tag]   - with a tag (e.g. v1.3.1) it must match "## Version" in the TOC.
# Prints the zip path on stdout; everything else goes to stderr.
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(sed -n 's/^## Version:[[:space:]]*//p' Kibble.toc | tr -d '\r')
[ -n "$version" ] || { echo "no '## Version:' line in Kibble.toc" >&2; exit 1; }
if [ -n "${1:-}" ] && [ "${1#v}" != "$version" ]; then
	echo "tag $1 does not match the TOC version $version" >&2
	exit 1
fi

files=(Kibble.toc Bindings.xml icon.png LICENSE README.md CHANGELOG.md)
while IFS= read -r line; do
	line=${line%$'\r'}
	case "$line" in ''|'#'*) ;; *) files+=("$line") ;; esac
done < Kibble.toc

mkdir -p dist
out="dist/Kibble-v$version.zip"
rm -f "$out"
git archive --format=zip --prefix=Kibble/ -o "$out" HEAD -- "${files[@]}"

# every file must really be in the archive
listing=$(unzip -Z1 "$out")
for f in "${files[@]}"; do
	grep -qx "Kibble/$f" <<<"$listing" || { echo "missing from the zip: $f" >&2; exit 1; }
done
unzip -l "$out" >&2
echo "$out"
