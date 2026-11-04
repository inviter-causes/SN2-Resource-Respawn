# Progress / Handoff

Last updated: 2026-11-04

## Current state: v2.1.1 built, NOT released (needs an in-game test first)

- **Code:** v2.1.1 committed and pushed on `main`. **No tag yet.** Tag `v2.1.1` only once
  Bon has uploaded it.
- **Zip:** `ResourceRespawn-2.1.1.zip` was built in the repo root by `./package.sh 2.1.1`.
  It is git-ignored; rebuild with the same command if it is missing.
- **Tests:** 76 mock tests green (38 main, 35 catalog, 3 for config.lua as Mod Manager
  sees it). A mutation check (client gate switched off) makes the 5 co-op tests fail, so
  they really bite.
- **Installed on this PC (2026-11-04):** UE4SS `UE4SS_v3.0.1-1028-gd7e7826d.zip`, from the
  official UE4SS-RE GitHub "experimental" release. That is the same commit Nexus mods/36
  ships, and its file list and sizes match the Nexus preview. SHA-256 `342d893c...c2c0b`.
  It was extracted into `A:\SteamLibrary\...\Binaries\Win64`, and `./deploy.sh` put 2.1.1
  in `ue4ss\Mods\ResourceRespawn`. Its UEHelpers has `GetAllPlayers` (via
  GameState.PlayerArray → PawnPrivate) and `GetKismetSystemLibrary`, and
  `GetWorldContextObject` returns the UWorld. All three match what 2.1.1 assumes.
- **Not verified:** the game has not been launched yet. Next: launch, load a save, check
  `ue4ss\UE4SS.log` for `ready v2.1.1` and for errors, confirm single-player still
  respawns, and confirm UE4SS Mod Manager's Configure window lists the 19 settings.
  Ideally also one co-op session on two PCs, to confirm the host's spawned deposit shows
  up for the client and can be mined.
- **`lang_local.lua` (personal Thai menu text) is gone:** it lived only in the old game
  folder on C:, which no longer exists, and it was never in git. Not needed for release.
- **`NEXUS.txt` is staged for 2.1.1** and no longer mirrors the live page until Bon
  uploads. Holding replies to modsyouknow / Fe1eNinamu24 plus a general post were drafted
  in chat on 2026-11-04 (Trussel card SUB-4466).
- **Trussel:** work is now tracked on the KBEONN board Subnautica > Resource Respawn
  (SUB-4458..4467, history backfilled with real dates). Bon asked for every job to get a
  card there, dated the day it is finished.
- **Command center `STATUS.md`:** `../Bon-Skill-Manager` is not on this PC, so it is not
  updated. Do it at release time.

## Open bug: Axum culture vanishes after respawning (SUB-4488)

Fe1eNinamu24 reported this on Nexus at 2026-11-04 14:12. They harvest the culture, wait out
the timer, and when they get close it's gone, in solo and in co-op alike. Axum is
`AxumBioprintCulture_Cage`, which is not a `resourcedeposit`/`resourcenode`, so
`static = false`: the mod restores it in place (`bringBack`: new random ResourceId, clear
the flag, OnRep) whenever the husk is in view, and spawns a fresh one otherwise.

**Found and fixed (2026-11-04, from the first trace run, `UE4SS.log` 14:43-14:51):**
- Axum near the player works fine. Harvesting sets the cage to `gathered=true
  destroyed=true`, and it lingers about 30s before the actor goes away. So it actually
  takes the absence → spawn path, not the in-place one. It respawned twice in a row with
  Bon standing there. Hypothesis 2 below is therefore moot for Axum.
- The real bug: due respawns fired with `player near the spot: false`, and 9 of them got
  back `new addr=0`. UE4SS returns an invalid object, not nil, when the engine refuses the
  spawn. The mod counted that as done, set `snapshot`/`watched`, and settled the pending
  entry. On return the spot was empty and never queued again. This is not Axum-specific
  (silver and slugs were hit too); Axum is just rare enough that people notice.
- Fix: a due entry fires only after a player has been near the spot for `SETTLE_SCANS = 2`
  scans in a row. `spawnReplacement` treats an invalid or 0-address result as a failure,
  and failures are retried every 10s, giving up only after 6 tries with a player present.
  Tests: section 14, and a mutation check of both fixes bites. The harness now puts
  spawned replacements into the mock world, and `quiesce` drains the queue near the
  origin, because walking away no longer drains it.
- Still to see in game: scenario B (harvest, swim more than 200m away, come back) with
  the fix in place.
- Side note: the log has no `ready v2.1.1` / `settings:` startup lines, even though the
  mod clearly ran. Worth a look; it may be UE4SS's log timing at startup.

**Second run (15:02-15:06), driven by the SN2-Mod-Settings session, not Bon:** an Axum
went `gone` at 15:04:58, was respawned at 15:05:28 near the player, and its spot was
re-queued at 15:05:33 because the new cage was not seen. The log is missing lines (a
`gone` with no earlier `seen`, which the code cannot produce; the game was still running,
so the file was likely not fully flushed). So it cannot say whether the game deleted the
cage or the mod failed to see it.
- **Fixed regardless:** positions are cached by actor address for up to 60s, and the
  engine recycles addresses. A replacement could inherit a far actor's stale position,
  look out of range, and get a second node stacked on it. `spawnReplacement` now seeds
  `locCache[newAddr]` with the spawn position. Test: section 15; the mutation check bites.
- **New trace:** with `Dev.Trace` set, every spawned address is checked on the next scan:
  `TRACE spawned X addr=N is in the engine's list` or `is NOT in the engine's list
  (removed already)`. That separates "the game deleted it" from "we missed it".
- The harness's spawn mock now returns a real mock actor (its own address, can reuse
  `world.recycleAddr`) and puts it into the world. 89 tests green.
- **Why that log was missing lines** (reported by the settings session): a second game
  instance started while the first was running (`steam://rungameid`), and it overwrote
  the head of `UE4SS.log`. Lines 1-48 of that file are from the second instance. Only
  trust a log from a single clean game launch, read after the game exits.
- **Toggle bug fixed (from the same run):** switching a resource OFF in the menu drops its
  nodes from `standing`, so the snapshot check queued every intact one as "harvested". If
  it was still OFF when they came due, the pending loop (which ignored the enabled list)
  would spawn a second node on top of each. Now the snapshot check skips disabled
  resources, and the pending loop drops entries whose resource is off. Test: section 16;
  the mutation check bites. 92 tests green.
- The settings session's compat folder `ue4ss/Mods/SN2ModSettings/enabled.txt` makes RR
  read `SN2ModSettings/saved/ResourceRespawn.lua` whenever it exists, overriding
  config.lua. That is why the 15:02 run briefly used 120s.

Original hypotheses, kept for the record:
1. **The timer fires while the player is far away.** The pending loop fires on time
   regardless of distance. With the husk out of view it spawns a new cage into an area
   that isn't loaded, while the old gathered cage still exists. On return, both stream in
   at the same spot. Candidate fix: only fire a due entry once a player is near the spot
   AND has been near on two scans in a row (area settled). That way the real husk is in
   view and gets restored in place, instead of a duplicate being spawned.
2. **Clearing the flag in place leaves the cage empty.** If the cage uses its ResourceId
   to decide its contents, `newGuid()` would leave it empty.

**Diagnostics added (dev only, off in releases):** `Dev.Trace = "axum"` logs `TRACE
seen/change/gone` per actor address. Verbose now logs the new address of each spawned or
restored actor, plus `due: spawning ... (player near the spot, husk in view)`.
`package.sh` refuses to build with Trace set.

**The game copy is in TEST mode right now:** `RespawnSeconds = 30`, `Verbose = true`,
`Trace = "axum"`, all marked `-- TEST (Axum bug)` in the deployed `config.lua`. The repo
copy is clean. Restore the game copy by running `./deploy.sh` after the test.

Test for Bon. Scenario A: harvest and stay within 100m for 1 minute. Scenario B: harvest,
swim more than 200m away for 1 minute, then come back. Note in each case whether the culture
is there and can be harvested, then read `ue4ss/UE4SS.log`.

## What changed in 2.1.1

- **Co-op:** `isNetClient()` asks `UEHelpers.GetKismetSystemLibrary():IsServer(world)`.
  On a client, `tick` returns before scanning and drops `snapshot` / `pending` /
  `watched`, so nothing fires later back in single player. If the question can't be
  answered, it assumes not-a-client, which keeps solo behaviour unchanged.
- **Range from every player:** `playerPositions()` uses `UEHelpers.GetAllPlayers()` (the
  game state's player list, cheap; no extra FindAllOf walk) and falls back to the local
  player. All three distance checks go through `isNear`.
- **config.lua:** player settings and the 16 resource toggles are top-level, each with a
  one-line comment directly above it. Dev flags moved into `Dev = {}`, which main.lua
  lifts onto `cfg`. The old nested `Resources = {}` still works via `cfgResource()`. New
  `Enabled` master switch.
- **deploy.sh:** tries the `A:\SteamLibrary` path first, warns when UE4SS is missing, and
  exits 1 when nothing was deployed.
- **This PC:** Python 3.12 was installed with winget (user scope) at
  `C:\Users\Bon\AppData\Local\Programs\Python\Python312`, with `lupa` installed via pip.
  It is not on Git Bash's PATH. Use the full path, or
  `PATH="/c/Users/Bon/AppData/Local/Programs/Python/Python312:$PATH" ./package.sh 2.1.1`.

## Previous: v2.1.0 fully released

- **GitHub:** commit `f571157` + `db2eaa0`, tag `v2.1.0`, pushed.
- **Nexus (mod 420):** verified live 2026-07-28 — version field 2.1.0, new zip uploaded,
  description and short description updated, changelog posted, 2.1.0 comment pinned,
  replies to Fe1eNinamu24 and Pippymint posted, requirements note fixed.
  All manual steps from the (now deleted) `drafts-2.1.0.txt` are done.
- **In-game:** 2.1.0 deployed and tested. 59 mock tests green (`tests/run.py`).

## What shipped in 2.1.0

- Troilite respawns (Mineralized Clinker = `BP_ResourceDeposit_DeepRootResonatableResource_C`,
  found via the dev-only catalog probe, `Scripts/catalog.lua`, `cfg.Catalog`)
- Refill on load: flagged husk at a spot never seen intact this session gets a 15s grace
- Respawned nodes keep their original scale
- Slider retuned: 5s–10min, default 120s; scan-cost note in the menu (EN + Thai via lang_local)

## 2026-11-04 triage (led to 2.1.1)

Two new Nexus comments; the notes below are what 2.1.1 was built from.

- **SN2ModSettings is gone.** Nexus mods/20 says "Removed by author". The author's GitHub
  (JustChaldea) also 404s, so no source is available; there is no license to fork under.
  New installs of Resource Respawn therefore run on `config.lua` only.
  - Alternatives checked: **UE4SS Mod Manager** (mods/34, AtilioA/UE4SS-mod-manager)
    has a "Configure mod" button that edits `Scripts/config.lua`. It only reads
    **top-level scalar** lines (depth 1 of the returned table), uses the comment line
    directly above a key as its description, and skips nested tables. So today it can
    show `RespawnSeconds` / `RefillOnLoad`, but NOT the per-resource toggles (they live in
    the nested `Resources` table), and it also shows the dev flags. Fix idea: flatten the
    resource toggles to top level and move dev flags into a nested `Dev = {}` table, while
    still reading the old layout.
  - **SN2MS_REBORN** (github whagan1310-droid/SN2MS_REBORN): F7 overlay that reads the old
    registration format, but bundles cheats + a `main.dll`, no license, 0 stars, last push
    2026-08-30. Not recommended as a dependency.
  - Mod Menu (mods/342) only covers its author's own mods. SN2 Mod Menu (mods/492) is a
    cheat menu, not a settings framework.
  - Option on the table: write our own settings menu (clean-room, same registration format
    so old mods keep working). Big job; would help SN2-Haste and SN2-Mod-Template too.
- **Co-op duplicate nodes** (Fe1eNinamu24, 2026-09-18): "double resources spawn, you break
  one and can't break the other". Diagnosis: every player's copy of the mod spawns its own
  replacement. The host's spawn replicates to clients (real, harvestable); the client's
  own spawn exists only on that client (fake, can't be mined). Refill on load makes it
  show up right as you enter an area. Fix plan: only act when
  `KismetSystemLibrary:IsServer(world)` is true (host / solo); clients skip the scan
  entirely. Also measure distance from every player's pawn on the host, not just the
  host's, so spots near a client respawn too. Needs a real co-op test (two PCs).
- **This PC:** the game is installed at `A:\SteamLibrary\steamapps\common\Subnautica2`, and
  it has **no UE4SS installed**. `deploy.sh` still points at the old `C:\Program Files
  (x86)\Steam` path, and the Vortex folder is gone. Latest UE4SS on Nexus mods/36 is commit
  `d7e7826d` (2026-08-20, replaces 3.0.1). Mod 2.1.0 is untested on that build.

## Open items (not started, no commitments)

- **Co-op verification** of deposit spawning on two PCs (2.1.1 assumes that a deposit the
  host spawns replicates to clients; the bug report suggests it does, but this is not
  confirmed). If it does NOT replicate, the fallback is the `ServerExecRPC` /
  `ClientMessage` pattern (see the PaintBrush mod) to tell clients where to spawn.
- **Own settings menu:** a separate session is building a clean-room SN2ModSettings
  replacement in `D:\Personal\SN2-Mod-Settings`. Once it ships, have ResourceRespawn
  register with it too (today `writeRegistration` only writes when
  `SN2ModSettings/enabled.txt` exists).
- **Yield variance:** a respawned node rolls its own piece count. Investigated and
  declined — the roll belongs to the game's blueprint. Documented on the page.
- **v-next idea:** hook the harvest event instead of polling `FindAllOf` (the remaining
  27–43ms scan hitch).

## Working notes

- The LIVE Nexus description is the source of truth; repo `NEXUS.txt` mirrors it.
- Public text rules: no em dashes, changelogs are bullets only, marketing versions drop
  the trailing .0 (v2.1) while files/tags keep full semver.
- `lang_local.lua` (Thai via the fr slot) lives only in the game folder, never packaged.
- Test with the lupa mock harness (`tests/run.py`, lua54 pinned) before any in-game test.
