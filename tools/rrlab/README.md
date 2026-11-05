# RRLab: scripted in-game test harness (dev only, never shipped)

A temporary UE4SS Lua mod that lets an agent drive Subnautica 2 without clicking. It reads
`cmd.txt` once a second, runs each line on the game thread and appends the results to
`out.txt`. `package.sh` doesn't include anything from `tools/`.

## Install / remove (Git Bash)

```bash
M=/a/SteamLibrary/steamapps/common/Subnautica2/Subnautica2/Binaries/Win64/ue4ss/Mods/RRLab
mkdir -p $M/Scripts && cp tools/rrlab/main.lua $M/Scripts/ && cp tools/rrlab/scripts/*.lua $M/ && touch $M/enabled.txt
# remove: rm -rf $M   (or just delete enabled.txt to switch it off)
```

`main.lua` hard-codes this machine's game path (`DIR`). Tell the SN2-Mod-Settings
session before using the game, because it shares the folder.

## Use

- `tools/rrlab/lab.sh "<command>" [timeout_s]` sends one command and prints its output.
  Commands: `ping`, `where`, `quit`, `do <file.lua>` (runs a script from the mod folder with
  the `LAB` helpers in scope). Set parameters with a one-line script, for example
  `echo 'LAB.PICKCLS = "ResourceNode_Quartz"' > $M/p_cfg.lua`.
- `tools/rrlab/boot.sh` (after launching via `steam://rungameid/1962700`): loads savegame_8
  through `UWELobbyGameMode:LoadLocalGame`, skips the Pioneer screen with
  `WBP_CharacterSelectScreen_C:DevSelectCharacterAndCloseScreen`, then waits for a pawn.

## Scripts

| script | what it does |
|---|---|
| p_das | every `UWEWorldPopResourceDA` with its `TimeToRespawnSeconds` |
| p_sub2 / p_state | `UWEWorldPopSubsystem` maps: gather states, respawn timers, pending |
| p_hist / p_dbg | loaded resource actors by class, and the nearest ones |
| p_tp / p_go | teleport next to the nearest resource (`LAB.TPCLS`) / to `LAB.GO` |
| p_pick / p_pick2 | real pickup via `UWEInventoryRouterComponent:PickupActor` (loose items only) |
| p_setresp / p_setall | set native respawn time on matching DAs |
| p_snap / p_diff / p_watch2 | snapshot nearby spots, then show what changed / watch one id |
| p_station | scanner stations in the world and the filter assets |

## Known crashers (don't)

- `SN2CheatManager` built by hand: `ContinueGame` crashes, `LoadGame` does nothing.
- `UWEWorldPop2BlueprintFunctionLibrary:GetAllResources…Filtered` with soft class pointers
  from Lua: access violation.
- Teleporting back and forth over kilometres several times in a row: GPU crash.
- A locked PC stalls the game thread (commands queue up until it's unlocked).
- Breaking a node from code (`UWEBreakableStatics:BreakBreakableNoAbility`, `OnBreak`)
  returns success but doesn't break it, so deposits need a real hit by a player.
