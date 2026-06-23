-- ResourceRespawn config (defaults / used when SN2ModSettings is absent)
--
-- If SN2ModSettings is installed -> adjust everything from the in-game menu.
-- No need to edit this file (menu values override it).
--
-- If SN2ModSettings is absent -> the mod reads its values from here.
return {
    CheckIntervalMs  = 5000,     -- how often to scan (ms); 5000 so the 5s minimum respawn time is responsive
    DebugListNames   = false,    -- true = print every resource class name to the log
    DeepScan         = false,    -- diagnostic: log the nearest actors to the player (off; only for finding new resource classes)

    -- Global respawn time (seconds) applied to every resource.
    -- Overridden by the in-game slider (min 5, step 5).
    RespawnSeconds = 300,

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
