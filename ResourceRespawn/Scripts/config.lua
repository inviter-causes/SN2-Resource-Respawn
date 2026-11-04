-- ResourceRespawn settings
--
-- How to change them:
--   * UE4SS Mod Manager (Nexus mod 34): click "Configure mod" next to ResourceRespawn.
--   * By hand: edit the values below in Notepad, save, then restart the game.
--   * SN2ModSettings, if you still have it installed: its in-game menu overrides this file.
--
-- Keep each setting on its own line, with its description in the comment line right
-- above it. That is the layout UE4SS Mod Manager reads.
return {
    -- Master switch. false = the mod does nothing.
    Enabled = true,

    -- Respawn time in seconds for every resource (5 to 600). 120 is a good default. Below about 50 the mod scans every 5s, which costs a little more performance.
    RespawnSeconds = 120,

    -- Refill on load: spots emptied in an earlier session (or before installing the mod) come back about 15s after you get near them, instead of waiting the full respawn time again.
    RefillOnLoad = true,

    -- Titanium (true = respawns)
    Titanium = true,
    -- Copper
    Copper = true,
    -- Quartz
    Quartz = true,
    -- Salt
    Salt = true,
    -- Water Slug
    WaterSlug = true,
    -- Lead
    Lead = true,
    -- Silver
    Silver = true,
    -- Sulfur
    Sulfur = true,
    -- Gold
    Gold = true,
    -- Lithium (not the Clamthulu Lithium Pearl)
    Lithium = true,
    -- Atacamite
    Atacamite = true,
    -- Celestine
    Celestine = true,
    -- Conduit Crystal (node name: Fulgurite)
    ConduitCrystal = true,
    -- Creature Enamel (node name: NeedleSharkNeedles)
    CreatureEnamel = true,
    -- Axum Bacterial Culture (only 5 in the game, normally never respawns)
    AxumCulture = true,
    -- Troilite (Mineralized Clinker)
    Troilite = true,

    -- Developer / diagnostic options. Leave these alone unless you are chasing a bug.
    -- They sit in a nested table on purpose, so UE4SS Mod Manager does not list them.
    Dev = {
        CheckIntervalMs  = 5000,   -- how often the mod wakes up (ms)
        DebugListNames   = false,  -- print every resource class name to the log
        DeepScan         = false,  -- log the actors nearest the player (finding new resource classes)
        Probe            = false,  -- reflection dump / spawn experiment (see Scripts/probe.lua)
        Catalog          = false,  -- dump nearby actors' class + properties (see Scripts/catalog.lua)
        Verbose          = false,  -- log each queue/respawn to UE4SS.log
        Profile          = false,  -- log where each scan spends its time (chasing hitches)
    },
}
