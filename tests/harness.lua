-- Mock UE4SS environment + tests for ResourceRespawn/Scripts/main.lua
--
-- main.lua is loaded unmodified. Everything it reaches for (FindAllOf, UEHelpers, the
-- actor reflection API, LoopAsync) is faked here, so the whole scan can be driven from
-- Lua without launching the game.
--
-- Run via tests/run.py, which sets up a temp CWD containing a fake SN2ModSettings tree.

local SCRIPTS = ...
package.path = SCRIPTS .. "/?.lua;" .. package.path

--------------------------------------------------------------------------------
-- Controllable clock. Cooldowns are in os.time() seconds, so tests advance this
-- instead of sleeping.
--------------------------------------------------------------------------------
local CLOCK = { t = 100000 }
os.time = function() return CLOCK.t end

--------------------------------------------------------------------------------
-- Instrumentation
--------------------------------------------------------------------------------
local counts = {}
local function bump(k) counts[k] = (counts[k] or 0) + 1 end
local function reset() counts = {} end
local function got(k) return counts[k] or 0 end

-- Count opens per path so the settings-file read can be observed directly.
local realopen = io.open
local opens = {}
io.open = function(path, mode)
    opens[path] = (opens[path] or 0) + 1
    return realopen(path, mode)
end
local function opensOf(suffix)
    local n = 0
    for p, c in pairs(opens) do
        if p:sub(-#suffix) == suffix then n = n + c end
    end
    return n
end

--------------------------------------------------------------------------------
-- World + actor mocks
--------------------------------------------------------------------------------
local world = { nodes = {}, player = { X = 0, Y = 0, Z = 0 } }
local nextAddr = 4096

local function makeClass(name)
    local full = "BlueprintGeneratedClass /Game/Res/" .. name .. "." .. name .. "_C"
    local fname = { ToString = function() return name end }
    return {
        GetFName    = function() return fname end,
        GetFullName = function() return full end,
    }
end

local function makeActor(name, x, y, z, gathered, scale)
    nextAddr = nextAddr + 8
    local cls = makeClass(name)
    local s = scale or 1.0
    local a
    a = {
        __addr  = nextAddr,
        __alive = true,
        bHasBeenGathered       = gathered and true or false,
        bActorIsBeingDestroyed = false,
        ResourceId = { A = 0, B = 0, C = 0, D = 0 },
        GetAddress          = function() bump("GetAddress") return a.__addr end,
        K2_GetActorLocation = function() bump("GetLoc") return { X = x, Y = y, Z = z } end,
        K2_GetActorRotation = function() bump("GetRot") return { Pitch = 0, Yaw = 0, Roll = 0 } end,
        GetActorScale3D     = function() bump("GetScale") return { X = s, Y = s, Z = s } end,
        GetClass            = function() return cls end,
        IsValid             = function() return a.__alive end,
        OnRep_HasBeenGathered = function() bump("OnRep") end,
        K2_DestroyActor     = function() a.__alive = false bump("Destroy") end,
    }
    return a
end

local function addNode(...) local a = makeActor(...) world.nodes[#world.nodes + 1] = a return a end

local function removeNode(target)
    for i, a in ipairs(world.nodes) do
        if a == target then table.remove(world.nodes, i) return end
    end
end

--------------------------------------------------------------------------------
-- UE4SS globals
--------------------------------------------------------------------------------
FindAllOf = function(cls)
    bump("FindAllOf")
    local out = {}
    if cls == "UWEWorldPopResourceBaseActor" then
        for _, a in ipairs(world.nodes) do
            if a.__alive then out[#out + 1] = a end
        end
    end
    return out
end

FindFirstOf = function(cls)
    if cls ~= "PlayerController" then return nil end
    return { Pawn = { K2_GetActorLocation = function() return world.player end } }
end

StaticFindObject = function(path)
    bump("StaticFindObject")
    return { __class = true, __path = path }
end

local spawned = {}
package.loaded["UEHelpers"] = {
    GetGameplayStatics = function()
        return {
            BeginDeferredActorSpawnFromClass = function(_, _, cls, xform)
                bump("BeginSpawn")
                return { __cls = cls, __xform = xform }
            end,
            FinishSpawningActor = function(_, a)
                bump("FinishSpawn")
                spawned[#spawned + 1] = a
            end,
        }
    end,
    GetKismetMathLibrary = function()
        return { MakeTransform = function(_, loc, rot, scl) return { loc = loc, rot = rot, scl = scl } end }
    end,
    GetWorldContextObject = function() return { __wco = true } end,
}

package.loaded["lang"] = {
    code = "en",
    s    = function(k) return tostring(k) end,
    res  = function(k, w) return tostring(k) .. "." .. tostring(w) end,
}

-- The mod's own output is captured rather than printed, so test results stay readable.
-- Test output has to go through the real print, which the override below would swallow.
local realprint = print
local logs = {}
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    logs[#logs + 1] = table.concat(parts, " ")
end

local TICK
LoopAsync           = function(_, fn) TICK = fn end
ExecuteInGameThread = function(fn) fn() end

--------------------------------------------------------------------------------
-- Load the real mod
--------------------------------------------------------------------------------
dofile(SCRIPTS .. "/main.lua")
assert(TICK, "main.lua never registered a LoopAsync callback")

local function tick(n)
    for _ = 1, (n or 1) do TICK() end
end

-- Drain what the mod is holding between sections, so one test's leftovers cannot show up
-- as another test's spawn. The mod keeps respawned spots in `watched` and re-queues any
-- that sit empty while the player is next to them, which is correct behaviour and exactly
-- what leaks across tests. Moving the player out of range is what drops those entries;
-- jumping the clock first lets anything already queued fire and retire.
local function quiesce()
    world.nodes  = {}
    world.player = { X = 5e8, Y = 5e8, Z = 5e8 }
    CLOCK.t = CLOCK.t + 100000
    tick(5)
    world.player = { X = 0, Y = 0, Z = 0 }
    tick(1)
    reset()
end

--------------------------------------------------------------------------------
-- Test scaffolding
--------------------------------------------------------------------------------
local failures, passes = 0, 0
local function check(name, ok, detail)
    if ok then
        passes = passes + 1
        realprint(string.format("  PASS  %s", name))
    else
        failures = failures + 1
        realprint(string.format("  FAIL  %s   (%s)", name, tostring(detail)))
    end
end

local function section(t) realprint("") realprint("== " .. t .. " ==") end

--------------------------------------------------------------------------------
-- 1. Behaviour: a harvested deposit comes back
--------------------------------------------------------------------------------
section("1. harvest -> cooldown -> respawn")

world.nodes = {}
world.player = { X = 0, Y = 0, Z = 0 }
local node = addNode("BP_ResourceDeposit_Titanium", 1000, 0, 0, false)

tick()                                   -- sees the node standing
check("node seen while standing", got("GetRot") > 0, "no rotation read, node was not recorded")

removeNode(node)                         -- the player mines it: actor is destroyed
reset()
tick()                                   -- notices the spot is empty -> queues it
check("no spawn before the cooldown", got("BeginSpawn") == 0, got("BeginSpawn"))

CLOCK.t = CLOCK.t + 301                  -- default RespawnSeconds is 300
reset()
tick()
check("spawns a replacement once due", got("BeginSpawn") == 1, got("BeginSpawn"))
check("finishes the deferred spawn",    got("FinishSpawn") == 1, got("FinishSpawn"))

reset()
tick()
check("does not spawn again on the next scan", got("BeginSpawn") == 0, got("BeginSpawn"))

--------------------------------------------------------------------------------
-- 2. The optimisation: distant nodes must stay cheap
--------------------------------------------------------------------------------
section("2. cost of distant nodes")

quiesce()
local FAR = 600
for i = 1, FAR do addNode("BP_ResourceDeposit_Titanium", 1000000 + i, 0, 0, false) end

tick(3)                                  -- cold: coldBudget is 250/scan, so 3 scans cache all

reset()
tick()
check("no location reads once cached", got("GetLoc") == 0, got("GetLoc") .. " reads")
check("no rotation reads for distant nodes", got("GetRot") == 0, got("GetRot") .. " reads")
check("no scale reads for distant nodes", got("GetScale") == 0, got("GetScale") .. " reads")
check("one address lookup per node", got("GetAddress") == FAR, got("GetAddress") .. " vs " .. FAR)
check("one FindAllOf per scan", got("FindAllOf") == 1, got("FindAllOf"))

--------------------------------------------------------------------------------
-- 3. Settings are not re-read from disk on every scan
--------------------------------------------------------------------------------
section("3. settings file reads")

local before = opensOf("saved/ResourceRespawn.lua")
tick(8)                                  -- 8 scans, clock is not advanced -> inside the TTL
local after = opensOf("saved/ResourceRespawn.lua")
check("settings file not read every scan", (after - before) <= 1,
      string.format("%d reads over 8 scans", after - before))

--------------------------------------------------------------------------------
-- 4. Long run stays healthy (exercises the locCache pruner)
--------------------------------------------------------------------------------
section("4. long run + cache pruning")

quiesce()
for i = 1, 400 do addNode("BP_ResourceDeposit_Titanium", 2000000 + i, 0, 0, false) end
tick(5)

world.nodes = {}                         -- the whole area streams out
collectgarbage() collectgarbage()
local memBefore = collectgarbage("count")

tick(140)                                -- past PRUNE_EVERY (60) and PRUNE_STALE (60)

collectgarbage() collectgarbage()
local memAfter = collectgarbage("count")
check("cache memory released after actors vanish", memAfter < memBefore,
      string.format("%.0f KB -> %.0f KB", memBefore, memAfter))

-- And the mod still works afterwards.
world.nodes = {}
world.player = { X = 0, Y = 0, Z = 0 }
local n2 = addNode("BP_ResourceDeposit_Copper", 1200, 0, 0, false)
tick()
removeNode(n2)
tick()
CLOCK.t = CLOCK.t + 301
reset()
tick()
check("still respawns after a long session", got("BeginSpawn") == 1, got("BeginSpawn"))

--------------------------------------------------------------------------------
-- 5. The scan interval scales with the configured respawn time
--------------------------------------------------------------------------------
section("5. scan interval scales with respawn time")

quiesce()

local SAVED_PATH = "./ue4ss/Mods/SN2ModSettings/saved/ResourceRespawn.lua"
local function writeSaved(seconds)
    local f = assert(realopen(SAVED_PATH, "w"))
    f:write(string.format(
        "return { Enabled = true, RespawnSeconds = %d, Titanium = true }\n", seconds))
    f:close()
end

-- A short timer means the player wants a responsive respawn, so every wake must scan.
writeSaved(15)
CLOCK.t = CLOCK.t + 60      -- past the settings TTL, so the new value is picked up
tick(1)
reset()
tick(8)
check("short respawn time scans on every wake", got("FindAllOf") == 8, got("FindAllOf"))

-- A five-minute timer does not need a five-second scan, and the scan is what costs.
writeSaved(300)
CLOCK.t = CLOCK.t + 60
tick(1)
reset()
tick(8)
local scans = got("FindAllOf")
check("long respawn time scans less often", scans > 0 and scans <= 3,
      scans .. " scans per 8 wakes")

--------------------------------------------------------------------------------
-- 6. A batch coming due at once is spread over scans, and none of it is dropped
--------------------------------------------------------------------------------
section("6. respawn batches are spread out")

writeSaved(15)          -- one scan per wake again for the rest of the run
quiesce()

local batch = {}
for i = 1, 10 do
    batch[i] = addNode("BP_ResourceDeposit_Titanium", 1000 + i * 200, 0, 0, false)
end
tick()                                    -- all ten seen standing
for _, a in ipairs(batch) do removeNode(a) end
tick()                                    -- all ten detected as harvested and queued

CLOCK.t = CLOCK.t + 60                    -- every one of them comes due at the same moment
reset()
tick()
local first = got("BeginSpawn")
check("one scan does not spawn the whole batch", first > 0 and first <= 3,
      first .. " spawned in a single scan")

tick(4)
check("nothing queued is dropped", got("BeginSpawn") >= 10,
      got("BeginSpawn") .. " of 10 after 5 scans")

--------------------------------------------------------------------------------
-- 7. Troilite: the Mineralized Clinker respawns
--------------------------------------------------------------------------------
-- Its real class (catalog probe, 2026-07-26) is BP_ResourceDeposit_DeepRoot-
-- ResonatableResource_C - a normal world-pop resource. This pins the substring
-- match so a rename in RESOURCES silently dropping it fails a test.
section("7. Mineralized Clinker (Troilite) respawns")

quiesce()
local clinker = addNode("BP_ResourceDeposit_DeepRootResonatableResource", 1500, 0, 0, false)
tick()                                    -- seen standing
removeNode(clinker)                       -- blasted with the Resonator
tick()                                    -- absence noticed -> queued
CLOCK.t = CLOCK.t + 61                    -- past the 15s test cooldown
reset()
tick()
check("clinker spot spawns a replacement", got("BeginSpawn") == 1, got("BeginSpawn"))

--------------------------------------------------------------------------------
-- 8. The replacement keeps the original node's scale
--------------------------------------------------------------------------------
-- The game places some formations scaled up (the Mineralized Clinker in the wild is
-- larger than the blueprint's 1.0). Spawning at 1.0 shrank them; the transform must
-- carry the recorded scale through snapshot -> pending -> spawn.
section("8. respawn keeps the original scale")

quiesce()
local big = addNode("BP_ResourceDeposit_DeepRootResonatableResource", 1000, 0, 0, false, 2.5)
tick()                                    -- seen standing (scale recorded)
removeNode(big)                           -- blasted
tick()                                    -- queued
CLOCK.t = CLOCK.t + 61
reset()
tick()                                    -- respawns
check("spawned one replacement", got("BeginSpawn") == 1, got("BeginSpawn"))
local last = spawned[#spawned]
local scl = last and last.__xform and last.__xform.scl or nil
check("replacement carries the 2.5 scale",
      scl ~= nil and math.abs((scl.X or 0) - 2.5) < 0.001
      and math.abs((scl.Z or 0) - 2.5) < 0.001,
      scl and string.format("scale=(%s,%s,%s)", tostring(scl.X), tostring(scl.Y), tostring(scl.Z))
          or "no scale captured")

--------------------------------------------------------------------------------
-- 9. Refill on load (Fe1eNinamu24's request)
--------------------------------------------------------------------------------
-- On save load the game recreates previously-harvested nodes already flagged
-- (bHasBeenGathered=true). A flagged node at a spot the mod never saw intact was
-- harvested in an earlier session (or pre-mod): it gets a ~15s grace instead of the
-- full timer. A node harvested in front of the mod must still wait the full timer.
section("9. refill on load")

-- One spawn per distinct X coordinate, so the checks are immune to other spots
-- re-queueing in the background.
local function spawnsAt(x)
    local n = 0
    for _, sp in ipairs(spawned) do
        if sp.__xform and sp.__xform.loc and sp.__xform.loc.X == x then n = n + 1 end
    end
    return n
end

writeSaved(120)              -- long timer makes the grace visible; scans every 2nd wake
quiesce()
CLOCK.t = CLOCK.t + 60       -- past the settings TTL
tick(2)

-- The load case: the node appears already flagged, never seen intact.
-- Coordinates in this section are unique across the whole file: spawnsAt() counts the
-- accumulated spawn list, so reusing an earlier section's X would double-count.
addNode("BP_ResourceDeposit_Titanium", 13600, 0, 0, true)
tick(2)                      -- flagged at an unwatched spot -> queued with the grace
CLOCK.t = CLOCK.t + 16       -- grace is 15s, full timer would be 120s
tick(2)
check("pre-session harvest refills after the grace", spawnsAt(13600) == 1,
      spawnsAt(13600) .. " spawns at the spot")

-- The live case: seen standing first, then harvested in front of the mod.
local live = addNode("BP_ResourceDeposit_Titanium", 14000, 0, 0, false)
tick(2)                      -- standing -> snapshotted and watched
live.bHasBeenGathered = true -- harvested live (husk stays, flagged)
tick(2)                      -- queued with the FULL timer
CLOCK.t = CLOCK.t + 16
tick(2)
check("live harvest does NOT use the grace", spawnsAt(14000) == 0,
      spawnsAt(14000) .. " spawns too early")
CLOCK.t = CLOCK.t + 121
tick(2)
check("live harvest respawns after the full timer", spawnsAt(14000) == 1,
      spawnsAt(14000) .. " spawns at the spot")

-- The toggle: RefillOnLoad=false means even a never-seen flagged spot waits in full.
local f9 = assert(realopen(SAVED_PATH, "w"))
f9:write("return { Enabled = true, RespawnSeconds = 120, Titanium = true, RefillOnLoad = false }\n")
f9:close()
CLOCK.t = CLOCK.t + 60       -- settings TTL
tick(2)
addNode("BP_ResourceDeposit_Titanium", 14400, 0, 0, true)
tick(2)
CLOCK.t = CLOCK.t + 16
tick(2)
check("toggle off disables the grace", spawnsAt(14400) == 0,
      spawnsAt(14400) .. " spawns despite the toggle")

--------------------------------------------------------------------------------
section("summary")
realprint(string.format("  %d passed, %d failed", passes, failures))

if failures > 0 then
    realprint("")
    realprint("-- mod output --")
    for _, line in ipairs(logs) do realprint("  " .. line) end
end

return failures
