#!/usr/bin/env bash
# Deploy ResourceRespawn from this repo into the live game folder and the Vortex
# staging folder. Run from Git Bash:  ./deploy.sh
set -e

REPO_MOD="$(cd "$(dirname "$0")/ResourceRespawn" && pwd)"

GAME="/c/Program Files (x86)/Steam/steamapps/common/Subnautica2/Subnautica2/Binaries/Win64/ue4ss/Mods/ResourceRespawn"
VORTEX="/c/Users/Bon/AppData/Roaming/Vortex/subnautica2/mods/ResourceRespawn/ResourceRespawn"

for DST in "$GAME" "$VORTEX"; do
    if [ -d "$DST" ]; then
        mkdir -p "$DST/Scripts"
        cp -f "$REPO_MOD/Scripts/main.lua"   "$DST/Scripts/main.lua"
        cp -f "$REPO_MOD/Scripts/config.lua" "$DST/Scripts/config.lua"
        cp -f "$REPO_MOD/Scripts/lang.lua"   "$DST/Scripts/lang.lua"
        cp -f "$REPO_MOD/enabled.txt"        "$DST/enabled.txt"
        echo "deployed -> $DST"
    else
        echo "skip (not found) -> $DST"
    fi
done

echo "Done. Restart the game to load changes."
