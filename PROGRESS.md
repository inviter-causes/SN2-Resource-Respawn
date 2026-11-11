# Progress / Handoff

Last updated: 2026-11-05

## Current state: v2.1.1 LIVE on Nexus; scanner-station investigation done, v3 design awaiting Bon

- **Released:** v2.1.1 on [Nexus mods/420](https://www.nexusmods.com/subnautica2/mods/420),
  2026-11-05 12:31. Tag `v2.1.1` pushed. Working tree clean.
- **Live page verified by the agent:** version 2.1.1; the file is an *update* of the 2.1.0
  one (2.1.0 archived, so Vortex shows an update); the zip matches the repo byte for byte;
  the description is `NEXUS.txt`; the short description is updated; the only requirement
  is UE4SS SN2 (min 3.0.1); the changelog is in Logs; the "v2.1.1 is out!" post is pinned;
  replies to Fe1eNinamu24 and modsyouknow are posted; 3 links to Mod Settings Lite.
- **`NEXUS.txt` mirrors the live description again.** If you edit it, Bon pastes it onto
  the page; no new upload is needed for text-only changes.
- **Mod Settings Lite** (Bon's clean-room SN2ModSettings replacement, repo
  `D:\Personal\SN2-Mod-Settings`, private) went live 2026-11-05 at
  [mods/523](https://www.nexusmods.com/subnautica2/mods/523), v0.3.0 Beta. RR works with it
  unchanged: its compat folder `ue4ss/Mods/SN2ModSettings/enabled.txt` triggers
  `writeRegistration`. Its own repo and session own its progress.
- **Command center:** `../Bon-Dev-Hub` (formerly Bon-Skill-Manager). Its STATUS.md has the
  2026-11-05 entry for both repos; its registry is `repos.personal.json`.
- **Trussel:** every RR job is a card on KBEONN › Subnautica › Resource Respawn
  (`da97e81a-1b9b-4401-bd15-2ee70c2f932d`), dated the day it's finished. SUB-4458..4512,
  all Done. `delegate_task` / `report_step` get blocked by the permission classifier;
  create, comment, update and status changes work.

## Open items (no commitments)

- **Crash 2026-11-11 08:04 is a Mod Settings Lite bug, not an RR bug.** What happened:
  lobby Settings (OK) → load world → Settings (OK) → Quit to main menu → open Settings
  → `EXCEPTION_ACCESS_VIOLATION` ~1s later. The stack is nested UE4SS Lua inside a
  script hook (`WBP_Settings2Screen_C:BP_OnActivated`, Lite's `entry.lua`). Cause: Lite's
  `Tab:attach` keeps widgets from the previous open (`self.view.root`, `self.button`,
  `self.tabs`...) and calls `self.view:close()` → `RemoveFromParent` on the old page,
  which was freed with the old world. `pcall` can't catch an AV. Fix belongs in
  `../SN2-Mod-Settings` (drop every cached widget when the Settings screen's address or
  the world changes; never call methods on objects from a previous open). Crash folder:
  `%LOCALAPPDATA%\Subnautica2\Saved\Crashes\UECC-Windows-61E2…_0000`.
  `ue4ss/Mods/RRLab` was removed from the game folder 2026-11-11 (Bon's call); reinstall
  from `tools/rrlab` if v3 testing needs it.

- **Scanner Station doesn't show respawned nodes** (Fe1eNinamu24, Nexus, 2026-11-05).
  Bon replied 2026-11-05 15:33 (explained the cause, promised to try a fix, "no promises
  yet, I'll post here if it works"). Post the outcome under that comment either way.
  Cause found from the game's C++ headers (dumped 2026-11-05 to
  `ue4ss/CXXHeaderDump/` in the game folder; `Subnautica2.hpp`, `UWEWorldPopulation2.hpp`):
  `ASN2BaseScannerStation` fills its points from `ResourceBuffer:
  TArray<FUWESeededResourceInfo>`, i.e. the game's **seed list** of original resource spots
  (`UUWEWorldPop2BlueprintFunctionLibrary::GetAllResources…Filtered` with
  `FUWEWorldPop2Query{IncludedClasses = filter's WorldPopResourcesToFind, OnlyActive}`), not
  live actors. Once a spot is mined the game marks its seed GUID gathered; our spawned node
  is a new actor that isn't tied to that seed, so the spot stays "gathered" for the scanner.
  (Same reason v1's `newGuid` made re-streamed nodes come back: the mark is keyed by
  `ResourceId`.) The Axum cage is different: it carries a
  `SN2BaseScannerStationSignalComponent`, so it reaches the scanner through the signals
  subsystem and a mod-spawned Axum may already show up. Check it.
  - **The game has its own resource respawn, all reflected (Lua can read/write it):**
    `UUWEWorldPopResourceDA.TimeToRespawnSeconds` per resource type, and
    `UUWEWorldPopSubsystem` (server world subsystem) with `ResourcesToRespawn: TSet<FGuid>`,
    `RespawnTimers: TMap<FGuid,float>`, `PendingRespawnActors`, and the gathered marks
    `ResourceInstanceGatherStates: TMap<FGuid,uint8>`. The exe logs
    "Resource %s gathered with respawn time %f". This UE4SS build has Lua TMap/TSet types.
    `wpop.WPop2RespawnCooldownSeconds` is creatures only.
  - **Lab results (2026-11-05, savegame_8, `tools/rrlab`):**
    - Default `TimeToRespawnSeconds` is -1 (off) for almost every DA. The game already
      sets it for DeepRootResource_Large (Troilite) 2700, WaterSlug 2700, LithiumLoose 600,
      Lithium_ClamthuluPearl 600, FalseOysterRaion_Nodule 500.
    - `ResourceInstanceGatherStates` has one entry per loaded resource instance (all
      classes: ResourceNode, ResourceDeposit, WorldPopSpawned*, slugs), keyed by the actor's
      `ResourceId`. Clusters of loose pieces share one id. 0 = standing, 1 = gathered.
    - **Loose Quartz, real pickup** (`PickupActor`) with the DA at 30 s: gs 0→1,
      `RespawnTimers[id]` counts 30→0, then gs→0 and the piece stands again **live**.
    - **Quartz node broken by Bon** (real hit), DA at 30 s: gs→1 + 30 s timer, then gs→0,
      but **no actor while the area stays loaded**. After going 3 km away and back, the node
      was back at the same spot with the same id. The area unloads somewhere between 200
      and 400 m away (not pinned down).
    - So native = correct state (scanner, saves, co-op host) + respawn on area reload. RR
      is still needed for the live respawn while the player stays nearby.
    - Not yet checked: are native timers saved and resumed after save/load? Does a
      scanner station show the spot again (gs 0 should be enough, but nobody has looked)?
  - **Proposed RR v3 (awaiting Bon's go):**
    1. Set `TimeToRespawnSeconds` = RespawnSeconds on the DAs of enabled resources; restore
       the game's own values (remember them at startup) for disabled ones or when RR is off.
    2. Harvest detection = gather state flipping to 1 (by `ResourceId`), replacing the
       streaming heuristics (dyingSeen, 50 m rule). The due time = when the game's timer ends.
    3. Live respawn: when the game resets gs to 0 and the spot is empty with a player within
       150 m, spawn the node **with the original `ResourceId`** (so mining it goes through
       the game's normal gather path). Remove RR's own nodes once every player is >200 m
       away, so the game's re-stream copy never doubles up with ours.
    4. Refill on load: spots with gs=1 and no timer get a short native timer.
    5. Verify in a **Creative** save (Bon's request: no oxygen/hunger, FreeBuild for a
       scanner station): live respawn, re-stream without duplicates, save/load, scanner by eye.
  - Old test-tooling notes: the cheat manager the enabler creates in the lobby is a plain
    `CheatManager`. In the world it's `BP_SN2CheatManager_C`, but `WorldPopRemove` did
    nothing there. See tools/rrlab/README.md for the scripted boot and the known crashers.

- **Co-op on two PCs: never tested.** 2.1.1 assumes a deposit the host spawns replicates
  to clients (the bug report suggests it does). If not, the fallback is the
  `ServerExecRPC` / `ClientMessage` pattern (see the PaintBrush mod). Waiting on player
  reports; Fe1eNinamu24 was asked.
- **Vortex restore:** Bon wants it "later". The backup is
  `V:\04_Hobby\Game-Mods\SN2_Backup_2026-06-30` (see its README.txt). In Vortex, disable
  UE4SS EA1, both old ResourceRespawn entries, and SN2ModSettings (it clashes with Mod
  Settings Lite) before deploying. The mods are June versions, so check Nexus for updates.
  Don't copy the June saves over the current ones. Mod inventory at backup time: 17
  enabled, 1 disabled (RR 1.0.0), 12 removed (empty leftover folders).
- **README note out of date:** "the game never sets bHasBeenGathered on nodes the mod
  spawns" is false at least for Axum (the 2026-11-05 trace showed flags set).
- **Startup log lines missing:** `ready v2.1.1` / `settings:` don't appear in UE4SS.log
  even though the mod runs. Cosmetic; maybe UE4SS log timing.
- **Yield variance:** declined; the roll belongs to the game's blueprint.
- **v-next idea:** hook the harvest event instead of polling `FindAllOf` (the 27-43ms scan).

## What 2.1.1 changed (and why)

Triggered by two Nexus reports on 2026-11-04. modsyouknow: SN2ModSettings (mods/20) was
removed by its author, so there's no easy config. Fe1eNinamu24: co-op shows a ghost node
that won't break, and Axum disappears after respawning (solo and co-op).

- **Co-op:** `isNetClient()` = `KismetSystemLibrary:IsServer(world) == false`. A client
  returns before scanning and drops `snapshot` / `pending` / `watched` / `dyingSeen`.
  Unknown means not-a-client, which keeps solo behaviour unchanged.
- **Every player's range:** `playerPositions()` via `UEHelpers.GetAllPlayers()` (game-state
  player list, cheap), falling back to the local player. `isNear` = within 150m of any
  player.
- **Lost spots (the Axum bug):** due respawns fired with nobody near, the engine refused
  them (UE4SS returns an invalid object with address 0, not nil), and the mod counted that
  as done and forgot the spot. Now a due entry fires only after a player has been near for
  `SETTLE_SCANS = 2` scans; an invalid/0-address spawn is a failure, retried every 10s,
  dropped after 6 tries.
- **Stacked duplicates, 3 causes:** (a) streaming: a node leaving FindAllOf while you're
  inside 150m was counted as harvested. Now `wasHarvested` requires the node to have been
  *seen breaking* (`dyingSeen`, recorded only if the spot was standing on the previous
  scan and cleared when it stands again; 120s TTL) or a player within `HARVEST_RANGE = 50m`.
  (b) Turning a resource OFF made its nodes look harvested; now disabled resources are
  skipped and their queue entries dropped. (c) Recycled actor address: a fresh node
  inherited a far actor's cached position; `spawnReplacement` now seeds `locCache`.
- **config.lua flattened** so UE4SS Mod Manager's "Configure mod" lists all 19 settings
  (it only reads top-level scalars with the comment line directly above). Dev flags live
  in `Dev = {}`, lifted onto `cfg`. The 2.1.0 layout (`Resources = {}`) still works. New
  `Enabled` switch.
- **Diagnostics (dev only):** `Dev.Trace = "<class substring>"` logs `TRACE
  seen/change/gone` per actor address, and whether each spawned address is in the
  engine's list on the next scan. `package.sh` refuses to build with Trace set or any
  dev flag true.
- **deploy.sh:** finds the game on `A:\SteamLibrary`, warns if UE4SS is missing, and exits
  1 when nothing was deployed.
- **Tests:** 96 mock tests (`tests/run.py`: 58 main, 35 catalog, 3 for config.lua as
  Mod Manager sees it). Each fix was mutation-checked: switching it off makes its tests
  fail.

## Verified in game (2026-11-05, agent drove the game via computer-use)

- **Axum near:** harvest → back 30s later, confirmed in the engine's list, no re-queue.
- **Axum far:** harvest, swim up 240m, timer passes and nothing fires; come back, the game
  streams in the gathered husk, and the mod restores it in place after 2 scans; harvestable.
- **Load-restored husks:** full and harvestable. Once restored, streaming out no longer
  re-queues them.
- **Swimming around:** streamed-out nodes log `ignored ... streamed out`; no false `queued`.
- **Not done in game after the final fix:** a real harvest, because the game stopped
  accepting synthetic input. Covered by the 50m rule and section 17.

## This machine (Windows, games box)

- Game: `A:\SteamLibrary\steamapps\common\Subnautica2` (Steam app 1962700). Saves:
  `%LOCALAPPDATA%\Subnautica2\Saved\SaveGames`; `savegame_8` is the test save, standing
  next to an Axum at 481m.
- UE4SS **d7e7826d** installed (GitHub "experimental" build, byte-identical to Nexus mods/36,
  sha256 `342d893c…c2c0b`). Game copy of RR is normal (no TEST lines). The menu-saved
  `ue4ss/Mods/SN2ModSettings/saved/ResourceRespawn.lua` has RespawnSeconds = 120, and it
  overrides config.lua while it exists.
- Python 3.12 at `C:\Users\Bon\AppData\Local\Programs\Python\Python312` (+ lupa, msgpack,
  user site), not on Git Bash's PATH. Run tests with the full path; package with
  `PATH="/c/Users/Bon/AppData/Local/Programs/Python/Python312:$PATH" ./package.sh 2.1.1`.
- The personal `lang_local.lua` (Thai menu) is gone; it lived only in the old C: game
  folder.

## Traps

- **Lab mod / scripted tests (2026-11-05):** `ue4ss/Mods/RRLab` (temporary) reads
  `cmd.txt` once a second and runs each line in the game thread; output goes to `out.txt`.
  Helper: `lab.sh "<cmd>"` in the session scratchpad. Notes:
  - The CheatManagerEnabler gives a plain `CheatManager`. A hand-built `SN2CheatManager`
    (StaticConstructObject) is never initialised: `LoadGame` silently does nothing, and
    `ContinueGame` **crashed the game** (null read at 0x8, probably
    `GameplayMessageSubsystem`). Don't use its cheats.
  - To load a save from code, use the lobby game mode instead:
    `FindFirstOf("UWELobbyGameMode"):LoadLocalGame("savegame_8", "", "")` (works), then
    `WBP_CharacterSelectScreen_C:DevSelectCharacterAndCloseScreen()` to get past the
    Pioneer screen. `tools/rrlab/boot.sh` does both.
  - After a crash, the next launch shows a Windows "game might not have exited correctly"
    box. Synthetic clicks don't reach it, so Bon has to press OK, and the game then quits;
    launch again.
  - **A locked PC stalls everything:** computer-use only sees a grey lock screen, and
    `ExecuteInGameThread` work never runs (the game keeps using CPU but doesn't tick UE4SS
    callbacks). Bon has to unlock the PC.
  - **Don't call `open_application` on the game while it's running.** It starts a second
    instance, which overwrites UE4SS.log and then exits.

- **computer-use in SN2:** grant the game by exe path
  (`A:\SteamLibrary\...\Win64\Subnautica2-Win64-Shipping.exe`). Hover before clicking
  (mouse_move near, then onto the button, then press): instant clicks often don't
  register in menus. Moving the mouse turns the camera in game, so fire without moving.
  The Axum needs the Sonic Resonator (hotbar 5; hold LMB ~3s). Up/down = Space/C; the pause
  menu shows coordinates. After a while the game can stop taking synthetic input, and
  only a restart fixes it. Quit through the in-game menu, not by killing the process.
- **UE4SS.log** is overwritten on each launch, and by a second game instance
  (`steam://rungameid` while running). Read it after a single clean launch, once the game
  has exited.
- **Shared game folder:** the SN2-Mod-Settings session also drives this game and writes
  `SN2ModSettings/saved/ResourceRespawn.lua`. Coordinate before testing.
- **Python on Windows** writes CRLF: write files as bytes / `newline="\n"`
  (`.gitattributes` forces LF anyway). Backslash paths inside heredoc Python break on
  `\U`; use raw strings or a script file.

## Working notes

- The LIVE Nexus description is the source of truth; `NEXUS.txt` mirrors it.
- Public text rules: no em dashes in new text, changelogs are one line per entry (Nexus
  adds the bullets; no "- "), marketing versions drop a trailing .0 (v2.1) while
  files/tags keep full semver.
- Release kit pattern: `drafts-X.Y.Z.txt` (steps in Thai + paste-ready English), deleted
  once live. Nexus upload: "Update existing file" + "Archive existing file", file version =
  the real version (it also sets the mod version), and fix the display name.
- Bon is not a programmer and replies in Thai. Agents run everything; Bon only clicks
  Nexus uploads/posts.

## History

- **2.1.1** (2026-11-05): see above.
- **2.1.0** (2026-07-27/28): Troilite respawns (`DeepRootResonatableResource`, found with the
  catalog probe), refill on load (15s grace), nodes keep scale, slider 5s-10min.
- **2.0.1** (2026-07-19): periodic stutter fixed, batched spawns, stride scales with timer.
- **2.0.0** (2026-07-14): mined deposits respawn live by spawning a new node.
- **1.0.0** (2026-06-23): first release.
- Alternatives checked when SN2ModSettings vanished (2026-11-04): UE4SS Mod Manager
  (mods/34, adopted); SN2MS_REBORN (unlicensed, bundles cheats + a DLL; rejected); Mod
  Menu mods/342 (its author's mods only); SN2 Mod Menu mods/492 (a cheat menu).
