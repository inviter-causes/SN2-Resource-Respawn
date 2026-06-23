-- ResourceRespawn config (defaults / used when SN2ModSettings is absent)
--
-- If SN2ModSettings is installed -> adjust everything from the in-game menu.
-- No need to edit this file (menu values override it).
--
-- If SN2ModSettings is absent -> the mod reads its values from here.
return {
    CheckIntervalMs  = 30000,    -- how often to scan (ms)
    DebugListNames   = false,    -- true = print every resource class name to the log
    DeepScan         = false,    -- diagnostic: log the nearest actors to the player (off; only for finding new resource classes)

    -- Respawn time (seconds) per rarity group
    GroupSeconds = {
        Common  = 300,    -- 5 min
        Medium  = 600,    -- 10 min
        Rare    = 900,    -- 15 min
        Special = 1800,   -- 30 min (finite specials such as Axum)
    },

    -- Enable/disable each resource (true = respawn it)
    Resources = {
        -- Common
        Titanium       = true,
        Copper         = true,
        Quartz         = true,
        Salt           = true,
        WaterSlug      = true,
        -- Medium
        Lead           = true,
        Silver         = true,
        Sulfur         = true,
        Gold           = true,
        Lithium        = true,   -- excludes LithiumPearl (Clamthulu)
        -- Rare
        Atacamite      = true,
        Celestine      = true,
        ConduitCrystal = true,   -- node class is "Fulgurite"
        CreatureEnamel = true,   -- node class is "NeedleSharkNeedles"
        -- Troilite is listed in the menu as "(unsupported)" and never acts (static actor)
        -- Special (finite)
        AxumCulture    = true,   -- only 5 in game, normally never respawns
    },
}
