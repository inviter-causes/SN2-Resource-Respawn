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
    Probe            = false,    -- diagnostic: reflection dump / spawn experiment (dev only; see Scripts/probe.lua)
    Catalog          = false,    -- diagnostic: dump nearby actors' class + properties (dev only; identify unsupported resources; see Scripts/catalog.lua)
    Verbose          = false,    -- log each queue/respawn to UE4SS.log (dev only)
    Profile          = false,    -- diagnostic: log where each scan spends its time (for chasing hitches)

    -- Spots emptied in an earlier session (or before the mod was installed) refill about
    -- 15s after you come near them, instead of waiting the full respawn time again.
    RefillOnLoad = true,

    -- Global respawn time (seconds) applied to every resource.
    -- Overridden by the in-game slider (min 5, max 600, step 5).
    -- 120 is the recommended default: fast enough to feel alive, and the scan runs only
    -- every 10s at this setting. Below ~50s the scan drops to every 5s (heavier).
    RespawnSeconds = 120,

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
        -- Special (finite)
        AxumCulture    = true,   -- only 5 in game, normally never respawns
        Troilite       = true,   -- Mineralized Clinker; node class is "DeepRootResonatableResource"
    },
}
