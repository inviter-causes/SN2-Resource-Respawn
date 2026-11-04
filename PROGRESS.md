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
- **Not verified:** nothing has run in the real game yet. UE4SS isn't installed on this
  PC. Before upload: install UE4SS d7e7826d, run `./deploy.sh`, then check single-player
  still respawns, and that UE4SS Mod Manager's Configure window lists the 19 settings.
  Ideally also one co-op session on two PCs, to confirm the host's spawned deposit shows
  up for the client and can be mined.
- **`NEXUS.txt` is staged for 2.1.1** and no longer mirrors the live page until Bon
  uploads. Holding replies to modsyouknow / Fe1eNinamu24 plus a general post were drafted
  in chat on 2026-11-04 (Trussel card SUB-4466).
- **Trussel:** work is now tracked on the KBEONN board Subnautica > Resource Respawn
  (SUB-4458..4467, history backfilled with real dates). Bon asked for every job to get a
  card there, dated the day it is finished.
- **Command center `STATUS.md`:** `../Bon-Skill-Manager` is not on this PC, so it is not
  updated. Do it at release time.

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
