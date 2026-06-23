# Resource Respawn

A UE4SS Lua mod for **Subnautica 2** that makes gathered resources come back after a
cooldown you control. Inspired by
[SlugRespawn](https://www.nexusmods.com/subnautica2/mods/269), generalized to many
harvestable resources and configurable in-game via
[SN2ModSettings](https://www.nexusmods.com/subnautica2/mods/20).

## What it does

Every `CheckIntervalMs` (default 5s) the mod scans loaded `UWEWorldPopResourceBaseActor`
instances. For each gathered node (`bHasBeenGathered == true`) whose class name matches
an enabled resource, it waits the **global respawn time** and then resets the node
(`bHasBeenGathered = false`, a fresh `ResourceId`, re-shown mesh) so the game treats it
as new.

One global respawn-time slider (5s–60min) applies to every resource, plus a per-resource
on/off toggle. Supported resources:

Titanium, Copper, Quartz, Salt, Water Slug, Lead, Silver, Sulfur, Gold, Lithium,
Atacamite, Celestine, Conduit Crystal, Creature Enamel, Axum Bacterial Culture.

> Some node class names differ from the item they yield: Conduit Crystal node =
> `Fulgurite`, Creature Enamel node = `NeedleSharkNeedles`, Axum = `AxumBioprintCulture_Cage`.
> Lithium is matched as `lithium_` to skip the Clamthulu-only "Lithium Pearl".

## What respawns when

- **Live (instant, on your timer):** small loose hand-picked pickups (e.g. small
  Titanium, Copper, Quartz) and Water Slug.
- **After a Save + reload + moving far away:** every medium/large node/deposit you break
  with a Sonic Resonator. The game keeps their "gathered" state in memory during a
  session, so the mod resets them once (no flicker) and they reappear once the area
  re-streams from a reload — after the set time has passed.
- **Not supported:** Troilite. Its "Mineralized Clinker" is a `StaticMeshActor` the mod
  can't reset; it's listed in the menu as `(unsupported)`.

## Configuration

- **With SN2ModSettings installed:** open Settings → Mods → Resource Respawn in-game.
  The mod self-registers its menu at startup.
- **Without it:** edit `ResourceRespawn/Scripts/config.lua`.

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
  ResourceRespawn/           <- deployable mod folder (zip this for Vortex)
    enabled.txt
    Scripts/
      main.lua
      config.lua
      lang.lua
```

## Deploy

Run `deploy.sh` (Git Bash) to copy the mod into the live game folder and the Vortex
staging folder. Restart the game to load changes (Lua loads at startup).

## Known issues

- Mined deposits/outcrops only reappear after a Save + reload + moving away (see
  "What respawns when").
- Troilite is shown but unsupported.

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
