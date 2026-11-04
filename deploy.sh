#!/usr/bin/env bash
# Deploy ResourceRespawn from this repo into the live game folder (and the Vortex staging
# folder, if Vortex is set up). Run from Git Bash:  ./deploy.sh
#
# The game has lived in more than one Steam library on this PC, so every known location
# is tried. A location that does not exist is skipped, not created: copying the mod into
# a folder UE4SS is not installed in would only look like a successful deploy.
set -e

REPO_MOD="$(cd "$(dirname "$0")/ResourceRespawn" && pwd)"

WIN64_CANDIDATES=(
    "/a/SteamLibrary/steamapps/common/Subnautica2/Subnautica2/Binaries/Win64"
    "/c/Program Files (x86)/Steam/steamapps/common/Subnautica2/Subnautica2/Binaries/Win64"
)
VORTEX="/c/Users/Bon/AppData/Roaming/Vortex/subnautica2/mods/ResourceRespawn/ResourceRespawn"

TARGETS=()
for W in "${WIN64_CANDIDATES[@]}"; do
    if [ -d "$W" ] && [ ! -d "$W/ue4ss/Mods" ]; then
        echo "UE4SS is not installed in: $W"
        echo "  install it first (Nexus subnautica2 mods/36), then run this again"
    fi
    TARGETS+=("$W/ue4ss/Mods/ResourceRespawn")
done
TARGETS+=("$VORTEX")

deployed=0
for DST in "${TARGETS[@]}"; do
    # Deploy where the mod already is, or where UE4SS's Mods folder is ready for it.
    PARENT="$(dirname "$DST")"
    if [ -d "$DST" ] || { [ -d "$PARENT" ] && [ "$(basename "$PARENT")" = "Mods" ]; }; then
        mkdir -p "$DST/Scripts"
        cp -f "$REPO_MOD/Scripts/"*.lua "$DST/Scripts/"   # main, config, lang (+ optional lang_local)
        cp -f "$REPO_MOD/enabled.txt"   "$DST/enabled.txt"
        echo "deployed -> $DST"
        deployed=$((deployed + 1))
    else
        echo "skip (not found) -> $DST"
    fi
done

if [ "$deployed" -eq 0 ]; then
    echo "Nothing deployed."
    exit 1
fi
echo "Done. Restart the game to load changes."
