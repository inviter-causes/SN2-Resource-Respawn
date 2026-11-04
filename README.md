# Resource Respawn

A UE4SS Lua mod for **Subnautica 2** that makes gathered resources come back after a
cooldown you control. Inspired by
[SlugRespawn](https://www.nexusmods.com/subnautica2/mods/269), generalized to many
harvestable resources. Configure it through `config.lua`, by hand or with
[UE4SS Mod Manager](https://www.nexusmods.com/subnautica2/mods/34)'s "Configure mod"
button. The in-game menu from SN2ModSettings still works for anyone who has it, but that
mod has been removed from Nexus.

## What it does

Gathered resources come back where they stood, on a cooldown you set — deposits
included, live, with no save reload.

## How it works

Mining a deposit **destroys** the actor: `bActorIsBeingDestroyed` flips to true, and
`UWEWorldPopResourceBaseActor` exposes no reset or respawn function (nor does anything
else in `/Script/UWEWorldPopulation2` — the resource subsystem, the global resource
storage and the seeded-resource octree all have zero callable functions). So clearing
`bHasBeenGathered` on a mined deposit is editing a corpse. That is why v1 could only get
them back after the area re-streamed.

v2 does not revive the node. Every `CheckIntervalMs` (default 5s) it snapshots the intact
nodes within ~150m of the player — class path, position, rotation. When a snapshotted spot
no longer has a node standing on it, that spot was harvested; once the cooldown elapses the
mod spawns a fresh actor of the same class there via
`UGameplayStatics::BeginDeferredActorSpawnFromClass` + `FinishSpawningActor`.

Nodes the game leaves alive after harvest (loose pickups, water slugs) take a cheaper
path: clear `bHasBeenGathered` in place.

Three constraints shape the implementation, each learned the hard way:

- **Never hold an actor between scans.** When an area unloads the engine frees those
  actors, and touching one afterwards is an access violation that kills the game — no
  `pcall` catches it. Everything remembered between scans is a class path and a
  transform; every actor touched comes from the current scan.
- **Never read a transform off a dying actor.** A harvested node reports its location as
  `(0,0,0)`, which once had the mod spawning deposits at the world origin, kilometres out
  to sea. Positions come from the snapshot taken while the node was standing.
- **Detect the harvest by absence, not by a flag.** Nodes the mod spawns itself are not
  registered with the game's world-population system, so the game never sets
  `bHasBeenGathered` on them. Watching for the node to be *gone* works for both.

One global respawn-time slider (5s–10min, default 120s) applies to every resource, plus a
per-resource on/off toggle and a **Refill on load** toggle: spots emptied in an earlier
session (or before the mod was installed) come back ~15s after you get near them, instead
of waiting the full timer again on every login. Supported resources:

Titanium, Copper, Quartz, Salt, Water Slug, Lead, Silver, Sulfur, Gold, Lithium,
Atacamite, Celestine, Conduit Crystal, Creature Enamel, Axum Bacterial Culture, Troilite.

> Some node class names differ from the item they yield: Conduit Crystal node =
> `Fulgurite`, Creature Enamel node = `NeedleSharkNeedles`, Axum = `AxumBioprintCulture_Cage`,
> Troilite's Mineralized Clinker = `DeepRootResonatableResource`.
> Lithium is matched as `lithium_` to skip the Clamthulu-only "Lithium Pearl".

## Known limitations

- **Range.** The mod only acts within ~150m of the player. That distance cull is what
  keeps the scan cheap; without it, reflecting over all ~1400 resource actors every 5s
  hitched the frame. A node harvested and then abandoned respawns when you return.
- **Respawned nodes are not saved.** They are spawned at runtime, so a save reload drops
  them — but on load the mod sees the spot is empty and refills it anyway.
- **Co-op.** Only the host's copy of the mod acts (`KismetSystemLibrary:IsServer`). A
  node the host spawns replicates to every player, but a node a client spawned existed
  only on that client and could not be mined. That was the 2.1.0 "duplicate node that
  won't break" bug. The host measures range from every player's pawn
  (`UEHelpers.GetAllPlayers`), so spots near a friend respawn too. A client with the mod
  installed simply idles. Still to verify in a real two-PC session: that the host's
  spawned deposit really shows up for clients.
- **Yield.** A respawned node rolls its own yield, so the piece count can differ from
  the original node's. That roll belongs to the game's blueprint, not the mod.

## Configuration

- **`ResourceRespawn/Scripts/config.lua`** is the main way to configure the mod (restart the
  game after a change). Every player setting, each resource toggle included, is a
  top-level line with its description in the comment directly above it. That is exactly
  what UE4SS Mod Manager's "Configure mod" window can list and edit: it reads top-level
  scalars only and skips nested tables. Developer flags therefore live in a nested
  `Dev = { ... }` table. The 2.1.0 layout (nested `Resources = {}`, flags at top level)
  is still honoured. `tests/run.py` checks the Mod Manager view.
- **SN2ModSettings** (removed from Nexus by its author): if it is still installed, the mod
  registers its in-game menu at startup, and the menu values override `config.lua`.

## Localization

Menu text lives in `ResourceRespawn/Scripts/lang.lua`. The mod reads the game's language
(`KismetInternationalizationLibrary:GetCurrentLanguage`) and serves the matching table,
falling back to English. To add a language, add a `strings.<iso> = { ... }` table
mirroring `strings.en` (e.g. `strings.de`, `strings.fr`); missing keys fall back to
English. The menu re-localizes when the player changes the game language and clicks Apply.

For personal builds, an optional `ResourceRespawn/Scripts/lang_local.lua` (git-ignored)
can add languages or aliases without touching the public file — `lang.lua` loads it at
startup if present.

## Layout

```
SN2-Resource-Respawn/        <- repo root
  README.md
  RESOURCES.md               <- resource reference (Thai)
  NEXUS.txt                  <- mod page description (BBCode)
  LICENSE
  deploy.sh                  <- copies the mod into the game + Vortex staging
  CHANGELOG.md
  ResourceRespawn/           <- deployable mod folder (zip this for Vortex)
    enabled.txt
    Scripts/
      main.lua
      config.lua
      lang.lua
      probe.lua              <- reflection probe, dev only (config.Probe)
```

## Deploy

Run `deploy.sh` (Git Bash) to copy the mod into the live game folder and the Vortex
staging folder. Restart the game to load changes (Lua loads at startup).

## Acknowledgments

This mod stands on the work of others in the Subnautica 2 modding community:

- **[SlugRespawn](https://www.nexusmods.com/subnautica2/mods/269)** by Casper — the
  original water-slug respawn mod whose approach this project generalizes.
- **[Mod Settings for Subnautica 2 (SN2ModSettings)](https://www.nexusmods.com/subnautica2/mods/20)**
  by JustChaldea — the in-game settings framework this mod registers its menu with.
- **[QuickStack](https://www.nexusmods.com/subnautica2/mods/128)** — reference for the
  localization approach (game-language detection + per-locale string tables).

Requires [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) for Subnautica 2. Built with the
help of Claude AI.
