-- Mock UE4SS reflection + tests for ResourceRespawn/Scripts/catalog.lua (v5)
--
-- catalog.lua is loaded unmodified and driven without a game. The mocks model the three
-- crashes that shaped it, and the discovery that motivated v5:
--
--   * crash 1: the LOBBY / main menu - FindAllOf("Actor") there touches transient menu
--     actors and dies. The sweep must never run while no world-pop resources exist.
--   * crash 2: the POST-LOAD STREAMING BURST - nothing may be scanned until the player
--     has stood still for STABLE_RUNS (3) consecutive runs.
--   * crash 3: CLASS-GRAPH REFLECTION - every mock class traps GetSuperStruct /
--     ForEachProperty and errors; the probe must never call them.
--   * v5 discovery: the Mineralized Clinker is in NEITHER the resource-base nor the
--     StaticMeshActor pool - only a gated sweep of "Actor" (deepScan's proven surface)
--     can find it. The mock clinker is likewise absent from every named pool.
--
-- Run from tests/run.py alongside harness.lua.

local SCRIPTS = ...
package.path = SCRIPTS .. "/?.lua;" .. package.path

--------------------------------------------------------------------------------
-- Capture what catalog writes, instead of touching the disk.
--------------------------------------------------------------------------------
local realopen = io.open
local captured = {}
io.open = function(path, mode)
    if mode == "w" then
        local buf = {}
        captured[path] = buf
        return {
            write = function(_, s) buf[#buf + 1] = s end,
            flush = function() end,
            close = function() end,
        }
    end
    return realopen(path, mode)
end
local function catalogText()
    for p, buf in pairs(captured) do
        if p:sub(-11) == "catalog.txt" then return table.concat(buf) end
    end
    return nil
end
local function clearCaptured() captured = {} end

--------------------------------------------------------------------------------
-- Reflection mocks
--------------------------------------------------------------------------------
local touched = { graph = 0 }

local function nameObj(s) return { ToString = function() return s end } end

-- Crash #3 regression trap: any walk of the class graph errors and is counted.
local function makeClass(name)
    local function graphBoom()
        touched.graph = touched.graph + 1
        error("class-graph reflection on " .. name .. " (crash #3)")
    end
    return {
        GetFName        = function() return nameObj(name) end,
        GetFullName     = function() return "Class /Script/Engine." .. name end,
        GetSuperStruct  = graphBoom,
        ForEachProperty = graphBoom,
    }
end

local DepositCls   = makeClass("BP_ResourceDeposit_Titanium_C")
local SmaCls       = makeClass("StaticMeshActor")
local GcCls        = makeClass("GC_MiningHit_C")
local ClinkerCls   = makeClass("BP_MineralizedClinker_C")  -- the unknown-class target
local ToolCls      = makeClass("BP_HeldResonator_C")

-- UE4SS does NOT return nil for a missing property - it returns an empty object
-- wrapper. Every mock actor does the same, so a type-unchecked read misclassifies
-- exactly like it did in the real game (the "bHasBeenGathered = UObject: ..." bug).
local MISSING_WRAPPER = {}

local function makeActor(cls, x, full, extra)
    local a = {
        IsValid             = function() return true end,
        K2_GetActorLocation = function() return { X = x, Y = 0, Z = 0 } end,
        GetClass            = function() return cls end,
        GetFullName         = function() return full end,
    }
    for k, v in pairs(extra or {}) do a[k] = v end
    return setmetatable(a, { __index = function() return MISSING_WRAPPER end })
end

-- A poison actor: reading anything off it bumps `touched[key]` and errors, standing in
-- for a native access violation. IsValid() alone is allowed (it is the gate).
local function makePoison(key, opts)
    opts = opts or {}
    touched[key] = 0
    local function boom() touched[key] = touched[key] + 1; error(key .. " actor touched") end
    return {
        IsValid             = function() return opts.valid == true end,
        K2_GetActorLocation = boom,
        GetClass            = boom,
        GetFullName         = boom,
    }
end

-- Per-class object pools + per-class FindAllOf call counts.
local POOLS = {}
local findCalls = {}
FindAllOf = function(c)
    findCalls[c] = (findCalls[c] or 0) + 1
    return POOLS[c]
end
local function callsTo(c) return findCalls[c] or 0 end

local PLAYER = { X = 0, Y = 0, Z = 0 }
local playerReady = true
FindFirstOf = function(c)
    if c ~= "PlayerController" then return nil end
    if not playerReady then return { Pawn = nil } end
    return { Pawn = { IsValid = function() return true end,
                      K2_GetActorLocation = function() return PLAYER end } }
end

--------------------------------------------------------------------------------
-- Log capture
--------------------------------------------------------------------------------
local logs = {}
local function log(s) logs[#logs + 1] = tostring(s) end
local function loggedContains(sub)
    for _, l in ipairs(logs) do if l:find(sub, 1, true) then return true end end
    return false
end
local function clearLogs() logs = {} end

local catalog = require("catalog")

--------------------------------------------------------------------------------
-- Scaffolding
--------------------------------------------------------------------------------
local failures, passes = 0, 0
local function check(name, ok, detail)
    if ok then passes = passes + 1; print(string.format("  PASS  %s", name))
    else failures = failures + 1; print(string.format("  FAIL  %s   (%s)", name, tostring(detail))) end
end
local function section(t) print("") print("== " .. t .. " ==") end
local function count(hay, needle)
    local n, i = 0, 1
    while true do
        local s = hay:find(needle, i, true)
        if not s then break end
        n = n + 1; i = s + 1
    end
    return n
end

-- Standing hazards.
local lobbyPoison  = makePoison("lobby",  { valid = true })
local streamPoison = makePoison("stream", { valid = true })

--------------------------------------------------------------------------------
-- 1. Lobby / menu: no world-pop resources -> bail, touch nothing
--------------------------------------------------------------------------------
section("1. lobby guard (crash #1 scenario)")

POOLS = {
    ["UWEWorldPopResourceBaseActor"] = {},
    ["Actor"]                        = { lobbyPoison },
}
playerReady = true
clearLogs(); clearCaptured()
catalog.run(log)

check("bails when no world-pop resources are present",
      catalogText() == nil, "a file was written in the lobby")
check("says it is skipping until a save is loaded",
      loggedContains("lobby/menu") or loggedContains("skipping"), table.concat(logs, " | "))
check("never sweeps FindAllOf(\"Actor\") in the lobby",
      callsTo("Actor") == 0, callsTo("Actor") .. " calls")
check("touches no lobby actor", touched.lobby == 0, touched.lobby .. " touches")

--------------------------------------------------------------------------------
-- 2. Post-load streaming burst: resources + player present, world NOT yet trusted
--------------------------------------------------------------------------------
section("2. stability gate (crash #2 scenario)")

local deposit = makeActor(DepositCls, 250,
    "BP_ResourceDeposit_Titanium_C /Game/Maps/Main/L_Main:PersistentLevel.Ti_7",
    { bHasBeenGathered = false })
local meshAsset = { GetFullName = function()
    return "StaticMesh /Game/Art/Environment/Rocks/SM_OR_LimestoneRubble_01a.SM_OR_LimestoneRubble_01a"
end }
local limestone = makeActor(SmaCls, 1200,
    "StaticMeshActor /Game/Maps/Main/L_Main:PersistentLevel.StaticMeshActor_UAID_1",
    { StaticMeshComponent = { StaticMesh = meshAsset } })
-- The clinker as v5 models it: its own unknown class, no gathered flag, no mesh field.
local clinker = makeActor(ClinkerCls, 200,
    "BP_MineralizedClinker_C /Game/Maps/Main/L_Main:PersistentLevel.BP_MineralizedClinker_C_UAID_9")
local heldTool = makeActor(ToolCls, 50, "BP_HeldResonator_C /Game/L:Tool")   -- player cluster
local gcEffect = makeActor(GcCls, 100, "GC_MiningHit_C /Game/L:GC")
local farOne   = makeActor(SmaCls, 5000, "StaticMeshActor /Game/L:Far")
local brokenGC = makePoison("broken", { valid = false })  -- mid-GC: IsValid()==false

-- The save just loaded: resources are in, but the world is mid-burst (poison present).
POOLS = {
    ["UWEWorldPopResourceBaseActor"] = { deposit },
    ["Actor"]                        = { streamPoison },
}
clearLogs(); clearCaptured()

catalog.run(log)   -- run 1: baseline (position now known); must not scan
catalog.run(log)   -- run 2: streak 1
check("asks the player to hold still", loggedContains("hold still"), table.concat(logs, " | "))
catalog.run(log)   -- run 3: streak 2
check("no dump during the streaming burst", catalogText() == nil, "dumped too early")
check("no sweep during the burst",
      callsTo("Actor") == 0 and touched.stream == 0,
      callsTo("Actor") .. " calls, " .. touched.stream .. " touches")

-- The burst settles: transient actors are gone, real world actors remain.
POOLS["Actor"] = { clinker, deposit, limestone, heldTool, gcEffect, farOne, brokenGC }
catalog.run(log)   -- run 4: streak 3 -> trusted -> dump
local txt = catalogText() or ""

check("dumps once the player has stood still for 3 runs", txt ~= "", "no file after streak")
check("announces the scan before it starts", loggedContains("scanning now"),
      table.concat(logs, " | "))
check("sweeps FindAllOf(\"Actor\") exactly once, at the dump",
      callsTo("Actor") == 1, callsTo("Actor") .. " calls")
check("tried the class-name guesses",
      callsTo("BP_MineralizedClinker_C") >= 1, callsTo("BP_MineralizedClinker_C") .. " calls")
check("never reads the mid-GC (invalid) actor", touched.broken == 0, touched.broken .. " touches")
check("logged a CATALOG summary", loggedContains("CATALOG:") and loggedContains("catalog.txt"),
      table.concat(logs, " | "))

--------------------------------------------------------------------------------
-- 3. Dump content: the unknown class is found, identities are read, no class graph
--------------------------------------------------------------------------------
section("3. dump content")

check("NEVER walks the class graph (crash #3 regression)",
      touched.graph == 0, touched.graph .. " graph walks")
check("has the header", txt:find("ResourceRespawn catalog", 1, true) ~= nil, "no header")
check("reports the candidate guesses as misses",
      txt:find("no guess matched", 1, true) ~= nil, "guess section missing")
check("nearest entry is the clinker (#1) with its real class name",
      (txt:match("%-%-%- #1.-\n") or ""):find("BP_MineralizedClinker_C", 1, true) ~= nil,
      txt:match("%-%-%- #1.-\n"))
check("shows the 2.0m distance on #1", txt:find("[2.0m]", 1, true) ~= nil, "no distance")
check("clinker flagged as 'other' kind (the real signal)",
      txt:find("kind  : other", 1, true) ~= nil, "no other-kind note")
check("deposit flagged as hookable with its state",
      txt:find("CAN hook", 1, true) ~= nil and txt:find("bHasBeenGathered = false", 1, true) ~= nil,
      "deposit not reported")
check("ONLY the deposit is called hookable (missing-property wrapper bug)",
      count(txt, "CAN hook") == 1, count(txt, "CAN hook") .. " hookable entries")
check("no wrapper garbage printed as state",
      txt:find("bHasBeenGathered = table", 1, true) == nil
      and txt:find("bHasBeenGathered = UObject", 1, true) == nil, "wrapper leaked into state")
check("limestone reports its mesh asset",
      txt:find("SM_OR_LimestoneRubble_01a", 1, true) ~= nil, "no mesh asset")
check("skips the player-attached cluster", txt:find("BP_HeldResonator", 1, true) == nil,
      "held tool leaked in")
check("skips GC_ effect actors", txt:find("GC_MiningHit", 1, true) == nil, "GC leaked in")
check("excludes actors beyond range",
      txt:find("L:Far", 1, true) == nil and count(txt, "--- #") == 3, "far actor leaked in")
check("the invalid actor does not appear in the dump",
      txt:find("went invalid", 1, true) == nil and count(txt, "--- #") == 3,
      "invalid actor leaked into the dump")

--------------------------------------------------------------------------------
-- 4. Dumps once per stillness, and movement re-arms the gate
--------------------------------------------------------------------------------
section("4. once per stillness, movement re-arms")

clearCaptured()
local sweepAfterDump = callsTo("Actor")
catalog.run(log)   -- streak 4: still standing there; must NOT dump again
check("does not dump again while still standing",
      catalogText() == nil and callsTo("Actor") == sweepAfterDump, "dumped twice")

PLAYER = { X = 100000, Y = 0, Z = 0 }              -- swims away
POOLS["Actor"] = { streamPoison }                  -- new area, new streaming burst
clearCaptured()
local sweepBefore = callsTo("Actor")

catalog.run(log)   -- moved -> streak reset; must not scan
catalog.run(log)   -- streak 1
catalog.run(log)   -- streak 2
check("no sweep while the new streak builds",
      callsTo("Actor") == sweepBefore and catalogText() == nil, "swept too early")
check("stream poison in the new area untouched", touched.stream == 0, touched.stream .. " touches")

POOLS["Actor"] = {
    makeActor(ClinkerCls, 100200, "BP_MineralizedClinker_C /Game/L:PersistentLevel.Clinker_2"),
}
catalog.run(log)   -- streak 3 -> dump at the new spot
check("dumps again after standing still at the new spot",
      (catalogText() or "") ~= "", "no file at second spot")

--------------------------------------------------------------------------------
-- 5. Player not ready: reports it, writes nothing, resets the streak
--------------------------------------------------------------------------------
section("5. player not ready")

playerReady = false
POOLS["Actor"] = { streamPoison }
clearLogs(); clearCaptured()
local sweepBase = callsTo("Actor")
catalog.run(log)
check("logs that the player is not ready", loggedContains("player location not ready"),
      table.concat(logs, " | "))
check("writes no file without a player", catalogText() == nil, "a file was written")

playerReady = true
catalog.run(log)   -- baseline again after the reset
catalog.run(log)   -- streak 1
catalog.run(log)   -- streak 2
check("streak restarted after losing the player",
      callsTo("Actor") == sweepBase and catalogText() == nil, "did not restart")
check("all poison actors and the class graph still untouched at the end",
      touched.lobby == 0 and touched.stream == 0 and touched.broken == 0 and touched.graph == 0,
      touched.lobby .. "/" .. touched.stream .. "/" .. touched.broken .. "/" .. touched.graph)

--------------------------------------------------------------------------------
section("summary")
print(string.format("  %d passed, %d failed", passes, failures))
if failures > 0 then
    print("")
    print("-- catalog output --")
    print(txt)
end

return failures
