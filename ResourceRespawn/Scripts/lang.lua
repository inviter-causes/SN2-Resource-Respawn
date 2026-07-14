-- ResourceRespawn localization.
-- Detects the game's language and serves the matching string table.
--
-- To add a language: add `strings.<iso> = { ... }` mirroring `strings.en`
-- (e.g. strings.de, strings.fr). Missing keys fall back to English, so a
-- partial translation is fine.

local lang = {}
local strings = {}

strings.en = {
    -- Mod manifest
    display        = "Resource Respawn",
    modDescription = "Gathered resources come back where they stood, on a cooldown you set.",

    -- Master switch
    enableTitle = "Enable mod",
    enableDesc  = "Master switch. When off, nothing respawns.",

    -- Global respawn-time slider
    timeTitle = "Respawn time (sec)",
    timeDesc  = "Cooldown for every resource. Mined deposits, loose pickups and water slugs all come back live, right where they stood — no save reload needed. Stay near the spot and it reappears once this time has passed.",

    -- Debug toggle
    debugTitle = "Debug: log resource names",
    debugDesc  = "Print every resource class name to the UE4SS log (use to find new resources to add).",

    -- Unsupported resources (listed for awareness only)
    unsupportedSuffix = " (unsupported)",
    unsupportedNote   = "Not supported yet: Mineralized Clinker is a static object the mod cannot reset, so toggling has no effect. ",

    -- Per-resource title + description
    resources = {
        Titanium       = { title = "Titanium",        desc = "Most-used base resource: bases, tools, vehicles, Titanium/Plasteel ingots." },
        Copper         = { title = "Copper",          desc = "Conductive metal for batteries, wiring and basic electronics. Often on cave walls." },
        Quartz         = { title = "Quartz",          desc = "Silica crystal for Glass and electronics. Common around coral domes in the Shallows." },
        Salt           = { title = "Salt",            desc = "Used for Glass, food, Isotonic Water and Power Cells. Found across the seabed." },
        WaterSlug      = { title = "Water Slug",      desc = "Passive creature; makes drinking water in the Fabricator. Common near the Lifepod." },
        Lead           = { title = "Lead",            desc = "Galena ore; radiation shielding. Sonic Resonator and Germanium ingot." },
        Silver         = { title = "Silver",          desc = "Air tanks, wiring kits and system chips. Gates much early-mid electronics." },
        Sulfur         = { title = "Sulfur",          desc = "Strong Acid, Repair Tool, advanced wiring. Volcanic / thermal-vent zones." },
        Gold           = { title = "Gold",            desc = "Thermal Plant and advanced wiring. Hot zones (needs heat resistance); often near Sulfur." },
        Lithium        = { title = "Lithium",         desc = "Smelts into Plasteel ingots for depth modules. Needed to dive past 300m." },
        Atacamite      = { title = "Atacamite",       desc = "Green crystal for Mangalloy ingot. Harvested with a Sonic Resonator." },
        Celestine      = { title = "Celestine",       desc = "Source of Strontium; used for the Tadpole Depth Module Mk.1." },
        ConduitCrystal = { title = "Conduit Crystal", desc = "Bioscanner and Advanced/Entangled Battery. Found below the Karakorum Power Plant." },
        CreatureEnamel = { title = "Creature Enamel", desc = "Enameled Glass. Break Enamel Husks inside the Needler nest." },
        AxumCulture    = { title = "Axum Bacterial Culture", desc = "Builds the Metal Farm. Rarest resource: only ~5 exist and never respawn (this mod overrides that)." },
        Troilite       = { title = "Troilite",        desc = "Used for Mangalloy ingot and Entangled Power Cell; found at Karakorum Metal Farms and farmable via a Metal Farm." },
    },
}

-- Optional personal overrides: if Scripts/lang_local.lua exists, it may add
-- languages or aliases (e.g. Thai served via the game's French slot, which the
-- SN2 Thai mods hijack) WITHOUT touching this public file. It returns a
-- function(strings) that mutates the table. A missing file is fine — the base
-- mod stays English. Keep lang_local.lua out of the public repo (git-ignored).
do
    local ok, override = pcall(require, "lang_local")
    if ok and type(override) == "function" then
        pcall(override, strings)
    end
end

-----------------------------------------------------------
-- Language detection
-----------------------------------------------------------
local kil = nil
do
    local ok, obj = pcall(function()
        return StaticFindObject("/Script/Engine.Default__KismetInternationalizationLibrary")
    end)
    if ok and obj then kil = obj end
end

lang.code    = "en"
lang.t       = strings.en
lang.strings = strings
lang.onRefresh = nil  -- set by main.lua to rewrite the registration on change

--- Re-detect the game language and swap the active string table.
function lang.refresh()
    if not kil then return end
    local ok, code = pcall(function() return kil:GetCurrentLanguage():ToString() end)
    if not ok or not code or code == "" then return end
    code = tostring(code)
    if code == lang.code then return end
    lang.code = code
    lang.t = strings[code] or strings[code:match("^([^%-]+)")] or strings.en
    if lang.onRefresh then pcall(lang.onRefresh) end
end

--- Top-level string, with English fallback.
function lang.s(key)
    local v = lang.t[key]
    if v ~= nil then return v end
    return strings.en[key] or key
end

--- Localized group display name, with English fallback.
function lang.group(key)
    local g = lang.t.groups and lang.t.groups[key]
    if g ~= nil then return g end
    return strings.en.groups[key] or key
end

--- Resource title/desc field, with English fallback.
function lang.res(key, field)
    local r = lang.t.resources and lang.t.resources[key]
    if r and r[field] ~= nil then return r[field] end
    local en = strings.en.resources[key]
    return (en and en[field]) or key
end

-- Detect on load (may still read "en" before the game applies saved settings).
lang.refresh()

-- Re-check after the game has applied its saved language.
if ExecuteWithDelay then
    pcall(function()
        ExecuteWithDelay(3000, function()
            if ExecuteInGameThread then ExecuteInGameThread(lang.refresh) else lang.refresh() end
        end)
    end)
end

-- Auto-refresh when the player clicks Apply in the game's settings.
do
    local applyPath = "/Script/Subnautica2.SN2SettingsViewModel:ApplySettings"
    local ok, applyFunc = pcall(function() return StaticFindObject(applyPath) end)
    if ok and applyFunc and RegisterHook then
        pcall(function() RegisterHook(applyPath, function() lang.refresh() end) end)
    end
end

return lang
