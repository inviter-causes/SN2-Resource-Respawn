# ResourceRespawn

A UE4SS Lua mod for **Subnautica 2** that makes gathered resources respawn after a
cooldown. Inspired by [SlugRespawn](https://www.nexusmods.com/subnautica2/mods/269),
but generalized to any harvestable resource and configurable in-game via
[SN2ModSettings](https://www.nexusmods.com/subnautica2/mods/20).

## What it does

Every `CheckIntervalMs` it scans `UWEWorldPopResourceBaseActor` instances. For each
gathered node (`bHasBeenGathered == true`) whose class name matches an enabled
resource, it waits the group's cooldown and then restores the node
(`bHasBeenGathered = false`, fresh `ResourceId`, re-shown mesh).

Resources are grouped by rarity, each group with its own respawn time:

| Group   | Default | Resources |
|---------|---------|-----------|
| Common  | 5 min   | Titanium, Copper, Quartz, Salt, Water Slug |
| Medium  | 10 min  | Lead, Silver, Sulfur, Gold, Lithium |
| Rare    | 15 min  | Atacamite, Celestine, Conduit Crystal, Creature Enamel |
| Special | 30 min  | Axum Bacterial Culture |

> Some node class names differ from the item they yield: Conduit Crystal node =
> `Fulgurite`, Creature Enamel node = `NeedleSharkNeedles`, Axum = `AxumBioprintCulture_Cage`.

## Configuration

- **With SN2ModSettings installed:** adjust everything in the in-game Settings → Mods
  tab. The mod self-registers its menu at startup.
- **Without it:** edit `ResourceRespawn/Scripts/config.lua`.

## Localization

Menu text lives in `ResourceRespawn/Scripts/lang.lua`. The mod reads the game's
language (`KismetInternationalizationLibrary:GetCurrentLanguage`) and serves the
matching table, falling back to English. To add a language, add a
`strings.<iso> = { ... }` table mirroring `strings.en` (e.g. `strings.de`,
`strings.fr`) — missing keys fall back to English. The menu re-localizes when the
player changes the game language and clicks Apply (a refresh / reopen of the Mods
tab shows the new text).

## Layout

```
ResourceRespawn/            <- repo root
  ResourceRespawn/          <- deployable mod folder (zip this for Vortex)
    enabled.txt
    Scripts/
      main.lua
      config.lua
  deploy.sh                 <- copies the mod into the game + Vortex staging
```

## Deploy

Run `deploy.sh` (Git Bash) to copy the mod into the live game folder and the Vortex
staging folder. Restart the game to load changes (Lua loads at startup).

## Acknowledgments

This mod stands on the work of others in the Subnautica 2 modding community:

- **[SlugRespawn](https://www.nexusmods.com/subnautica2/mods/269)** — the original
  water-slug respawn mod whose approach this project generalizes to any resource.
- **[Mod Settings for Subnautica 2 (SN2ModSettings)](https://www.nexusmods.com/subnautica2/mods/20)**
  by JustChaldea — the in-game settings framework this mod registers its menu with.
- **[QuickStack](https://www.nexusmods.com/subnautica2/mods/128)** — reference for the
  localization approach (detecting the game language via
  `KismetInternationalizationLibrary` and serving per-locale string tables).

Thank you to these authors. Requires [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) for Subnautica 2.
