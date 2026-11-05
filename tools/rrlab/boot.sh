#!/bin/bash
# waits for RRLab, loads savegame_8 through the lobby game mode, skips pioneer select, waits for a pawn
D=/a/SteamLibrary/steamapps/common/Subnautica2/Subnautica2/Binaries/Win64/ue4ss/Mods/RRLab
S="$(dirname "$0")/lab.sh"
for i in $(seq 1 60); do tail -1 $D/out.txt | grep -q "RRLab loaded" && break; sleep 2; done
for i in $(seq 1 15); do sleep 8; r=$("$S" "do p_loadlocal.lua" 15); echo "$r" | grep -q "LoadLocalGame called" && { echo "loaded call ok"; break; }; done
for i in $(seq 1 20); do sleep 8; r=$("$S" "do p_pickchar.lua" 15); echo "$r" | grep -q "calling Dev" && { echo "pioneer picked"; break; }; done
for i in $(seq 1 10); do sleep 5; r=$("$S" "where" 15); echo "$r" | grep -q "player at (0, 0, 0)\|no pawn\|no done" || { echo "$r" | grep "player at"; break; }; done
