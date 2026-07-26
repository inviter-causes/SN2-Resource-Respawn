#!/usr/bin/env bash
# Build the release zip for Nexus / Vortex.  Usage:  ./package.sh 2.0.0
#
# The archive contains the ResourceRespawn folder at its root, so Vortex installs it
# straight into ue4ss/Mods/ and a manual install is just "drag this folder in".
#
# Built from the repo, never from the live game folder — that one also holds
# lang_local.lua (a personal locale override) and stale probe output.
set -e

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "usage: ./package.sh <version>    e.g. ./package.sh 2.0.0"
    exit 1
fi

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/ResourceRespawn-$VERSION.zip"

# Ship only what the mod needs to run. probe.lua is a development-only reflection dump
# and lang_local.lua is a personal override; neither belongs in a public release.
FILES=(
    "ResourceRespawn/enabled.txt"
    "ResourceRespawn/Scripts/main.lua"
    "ResourceRespawn/Scripts/config.lua"
    "ResourceRespawn/Scripts/lang.lua"
)

for f in "${FILES[@]}"; do
    if [ ! -f "$ROOT/$f" ]; then
        echo "missing: $f"
        exit 1
    fi
done

# Refuse to ship with a diagnostic left switched on.
if grep -qE '^\s*(Probe|Catalog|Verbose|DeepScan|DebugListNames|Profile)\s*=\s*true' "$ROOT/ResourceRespawn/Scripts/config.lua"; then
    echo "refusing to package: a diagnostic flag is still true in config.lua"
    grep -nE '^\s*(Probe|Catalog|Verbose|DeepScan|DebugListNames|Profile)\s*=\s*true' "$ROOT/ResourceRespawn/Scripts/config.lua"
    exit 1
fi

# Sanity: the version the mod reports must match the one being packaged. Shipping a zip
# labelled 2.0.0 that announces itself as 1.1.0 in the log is a support nightmare.
if ! grep -q "version = \"$VERSION\"" "$ROOT/ResourceRespawn/Scripts/main.lua" \
   || ! grep -q "ready v$VERSION" "$ROOT/ResourceRespawn/Scripts/main.lua"; then
    echo "refusing to package: main.lua does not declare version $VERSION"
    grep -n 'version = "\|ready v' "$ROOT/ResourceRespawn/Scripts/main.lua"
    exit 1
fi

rm -f "$OUT"
cd "$ROOT"
python - "$OUT" "${FILES[@]}" <<'PY'
import sys, zipfile
out, files = sys.argv[1], sys.argv[2:]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for f in files:
        z.write(f, f)
PY

echo "built: $OUT"
python - "$OUT" <<'PY'
import sys, zipfile, os
z = zipfile.ZipFile(sys.argv[1])
print(f"  {os.path.getsize(sys.argv[1])} bytes")
for n in z.namelist():
    print("  " + n)
PY
