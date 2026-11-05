#!/bin/bash
# usage: lab.sh "<verb args>" [timeout_s]  -> sends one command to RRLab, waits for its done marker, prints its output
D=/a/SteamLibrary/steamapps/common/Subnautica2/Subnautica2/Binaries/Win64/ue4ss/Mods/RRLab
ID=$(date +%s%N | tail -c 7)
T=${2:-30}
start=$(wc -l < $D/out.txt)
echo "$ID $1" > $D/cmd.txt
for i in $(seq 1 $((T*2))); do
  if grep -q "<<done $ID>>" $D/out.txt; then break; fi
  sleep 0.5
done
tail -n +$((start+1)) $D/out.txt
grep -q "<<done $ID>>" $D/out.txt || echo "!! no done marker after ${T}s"
