# Progress / Handoff

Last updated: 2026-07-28

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
