# Progress / Handoff

Last updated: 2026-11-04

## Current state: v2.1.0 fully released

- **GitHub:** commit `f571157` + `db2eaa0`, tag `v2.1.0`, pushed. Working tree clean.
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

## 2026-11-04 triage (nothing shipped yet)

Two new Nexus comments. Holding replies drafted for Bon to post; no code changed yet.

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

- **Co-op verification** of deposit spawning. Lead: `ServerExecRPC` usage in the
  NotOnlyTitanium mod. Reports from users welcome per the mod page.
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
