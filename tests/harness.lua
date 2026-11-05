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
-- netClient: this machine joined someone else's co-op game (IsServer -> false).
-- others: extra players' positions, as a co-op host sees them.
local world = { nodes = {}, player = { X = 0, Y = 0, Z = 0 }, netClient = false, others = {} }
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
                if world.spawnInvalid then
                    -- What UE4SS hands back when the engine refuses the spawn: an object,
                    -- not nil, but invalid with address 0 (seen in the 2026-11-04 trace).
                    return { IsValid = function() return false end,
                             GetAddress = function() return 0 end }
                end
                -- A real mock actor, like the engine's: it has its own address, and
                -- FinishSpawningActor puts it in the world. world.recycleAddr makes it
                -- reuse an old actor's address, as the engine does.
                local path = cls and cls.__path
                local name = path and path:match("/Game/Res/([^%.]+)%.") or "BP_Unknown"
                local l, scl = xform.loc, xform.scl
                local a = makeActor(name, l.X, l.Y, l.Z, false, scl and scl.X)
                if world.recycleAddr then a.__addr, world.recycleAddr = world.recycleAddr, nil end
                a.__cls, a.__xform = cls, xform
                return a
            end,
            FinishSpawningActor = function(_, a)
                bump("FinishSpawn")
                spawned[#spawned + 1] = a
                -- Like the game: the replacement now stands in the world, so the next
                -- scan sees the spot occupied instead of empty.
                world.nodes[#world.nodes + 1] = a
            end,
        }
    end,
    GetKismetMathLibrary = function()
        return { MakeTransform = function(_, loc, rot, scl) return { loc = loc, rot = rot, scl = scl } end }
    end,
    GetWorldContextObject = function() return { __wco = true } end,
    GetKismetSystemLibrary = function()
        return { IsServer = function() bump("IsServer") return not world.netClient end }
    end,
    -- Every pawn in the game: the local player first, then anyone else.
    GetAllPlayers = function()
        local pawns = { { K2_GetActorLocation = function() return world.player end } }
        for _, o in ipairs(world.others) do
            local pos = o
            pawns[#pawns + 1] = { K2_GetActorLocation = function() return pos end }
        end
        return pawns
    end,
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
--
-- Since 2.1.1 a due respawn waits until a player is back next to the spot, so walking
-- away no longer drains the queue. Each round therefore comes back to the origin long
-- enough for everything queued there to fire (spawn budget is 3 a scan), then leaves
-- again so the freshly respawned spots drop out of `watched`.
local function quiesce()
    world.nodes  = {}
    for _ = 1, 3 do
        world.player = { X = 5e8, Y = 5e8, Z = 5e8 }
        CLOCK.t = CLOCK.t + 100000
        tick(5)
        world.player = { X = 0, Y = 0, Z = 0 }
        tick(8)
    end
    world.player = { X = 5e8, Y = 5e8, Z = 5e8 }
    world.nodes  = {}            -- drop the replacements the drain just spawned
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
-- 10. Co-op client stands aside (Fe1eNinamu24's duplicate-node report)
--------------------------------------------------------------------------------
-- A node a client spawns exists only on that client and cannot be mined, so a client
-- must never spawn, un-flag or destroy anything. The host's copy does the work.
section("10. co-op client never respawns")

writeSaved(15)
quiesce()
CLOCK.t = CLOCK.t + 60          -- settings TTL
tick(1)

local c1 = addNode("BP_ResourceDeposit_Titanium", 4100, 0, 0, false)
tick()                          -- seen standing while still the host / solo
world.netClient = true          -- now a client in someone else's game
reset()
removeNode(c1)                  -- harvested (or dropped out of replication relevance)
tick()
CLOCK.t = CLOCK.t + 61
tick(3)
check("client spawns nothing", got("BeginSpawn") == 0, got("BeginSpawn"))
check("client does not even scan", got("FindAllOf") == 0, got("FindAllOf") .. " scans")

addNode("BP_ResourceDeposit_Titanium", 4300, 0, 0, true)   -- husk handed back on join
reset()
tick()
CLOCK.t = CLOCK.t + 61
tick(3)
check("client does not refill husks either", got("BeginSpawn") == 0 and got("OnRep") == 0,
      got("BeginSpawn") .. " spawns, " .. got("OnRep") .. " OnRep")
check("client mode is logged once", (function()
    local n = 0
    for _, l in ipairs(logs) do if l:find("as a client", 1, true) then n = n + 1 end end
    return n == 1
end)(), "expected exactly one client-mode log line")

-- Back to solo: the spot that went dark while a client must not burst back as a free
-- node. The husk still sitting there is a genuine refill case and does come back.
world.netClient = false
world.nodes = {}
reset()
tick()
CLOCK.t = CLOCK.t + 61
tick(2)
check("no stale respawn after leaving co-op", spawnsAt(4100) == 0,
      spawnsAt(4100) .. " spawns at the old client-mode spot")

local c2 = addNode("BP_ResourceDeposit_Titanium", 4500, 0, 0, false)
tick()
removeNode(c2)
tick()
CLOCK.t = CLOCK.t + 61
tick()
check("host/solo respawns again afterwards", spawnsAt(4500) == 1,
      spawnsAt(4500) .. " spawns at the spot")

--------------------------------------------------------------------------------
-- 11. The host looks after spots near every player
--------------------------------------------------------------------------------
section("11. host covers a friend's spot far away")

quiesce()
world.player = { X = 0, Y = 0, Z = 0 }
world.others = { { X = 5000000, Y = 0, Z = 0 } }        -- a friend 50km away
local fr = addNode("BP_ResourceDeposit_Copper", 5000500, 0, 0, false)
tick()                          -- 5m from the friend, 50km from the host
removeNode(fr)                  -- the friend mines it
tick()
CLOCK.t = CLOCK.t + 61
tick()
check("spot next to a friend respawns", spawnsAt(5000500) == 1,
      spawnsAt(5000500) .. " spawns at the friend's spot")

world.others = {}               -- the friend logs off
local farAgain = addNode("BP_ResourceDeposit_Copper", 5001500, 0, 0, false)
tick()
removeNode(farAgain)
tick()
CLOCK.t = CLOCK.t + 61
tick()
check("with nobody there it is left alone", spawnsAt(5001500) == 0,
      spawnsAt(5001500) .. " spawns with no player in range")

--------------------------------------------------------------------------------
-- 12. config.lua layout (UE4SS Mod Manager can only edit top-level scalars)
--------------------------------------------------------------------------------
section("12. config.lua layout")

local cfgT = package.loaded["config"]
local RES = { "Titanium", "Copper", "Quartz", "Salt", "WaterSlug", "Lead", "Silver",
              "Sulfur", "Gold", "Lithium", "Atacamite", "Celestine", "ConduitCrystal",
              "CreatureEnamel", "AxumCulture", "Troilite" }
local missing = {}
for _, k in ipairs(RES) do
    if type(cfgT[k]) ~= "boolean" then missing[#missing + 1] = k end
end
check("every resource toggle is a top-level boolean", #missing == 0, table.concat(missing, ","))
check("no nested Resources table any more", cfgT.Resources == nil, "Resources still present")
check("dev flags live in Dev", type(cfgT.Dev) == "table" and cfgT.Dev.Probe == false
      and cfgT.Dev.Verbose == false and cfgT.Dev.CheckIntervalMs == 5000, "Dev table wrong")
check("Dev values are lifted for the mod", cfgT.CheckIntervalMs == 5000 and cfgT.Probe == false,
      "CheckIntervalMs=" .. tostring(cfgT.CheckIntervalMs))

-- A player who updates but keeps their 2.1.0 config.lua still has the nested
-- `Resources = { Copper = false, ... }` table. It must still be obeyed. The saved menu
-- file here names Titanium only, so Copper falls through to config.lua.
quiesce()
cfgT.Copper, cfgT.Resources = nil, { Copper = false }
CLOCK.t = CLOCK.t + 60          -- settings TTL, so the change is read
tick(1)
local oldCu = addNode("BP_ResourceDeposit_Copper", 4700, 0, 0, false)
local oldTi = addNode("BP_ResourceDeposit_Titanium", 4900, 0, 0, false)
tick()
removeNode(oldCu) removeNode(oldTi)
tick()
CLOCK.t = CLOCK.t + 61
tick()
check("old Resources table still switches a resource off", spawnsAt(4700) == 0,
      spawnsAt(4700) .. " copper spawns")
check("old layout leaves the others on", spawnsAt(4900) == 1,
      spawnsAt(4900) .. " titanium spawns")
cfgT.Copper, cfgT.Resources = true, nil

--------------------------------------------------------------------------------
-- 13. Dev.Trace logs an actor's life by address (diagnostic for the Axum report)
--------------------------------------------------------------------------------
section("13. Dev.Trace")

quiesce()
local function logsMatching(pat)
    local n = 0
    for _, l in ipairs(logs) do if l:find(pat, 1, true) then n = n + 1 end end
    return n
end
local before13 = { seen = logsMatching("TRACE seen"), change = logsMatching("TRACE change"),
                   gone = logsMatching("TRACE gone") }
cfgT.Trace = "axum"
local cage = addNode("BP_AxumBioprintCulture_Cage", 5100, 0, 0, false)
addNode("BP_ResourceDeposit_Titanium", 5300, 0, 0, false)   -- not traced
tick()
check("trace logs the cage when first seen", logsMatching("TRACE seen") == before13.seen + 1,
      logsMatching("TRACE seen") - before13.seen)
cage.bHasBeenGathered = true                                 -- the culture is taken
tick()
check("trace logs the state change", logsMatching("TRACE change") == before13.change + 1,
      logsMatching("TRACE change") - before13.change)
removeNode(cage)
tick()
check("trace logs the cage going away", logsMatching("TRACE gone") == before13.gone + 1,
      logsMatching("TRACE gone") - before13.gone)
tick(2)
check("an unchanged world logs nothing more",
      logsMatching("TRACE seen") == before13.seen + 1 and logsMatching("TRACE change") == before13.change + 1,
      "extra trace lines")
cfgT.Trace = ""

--------------------------------------------------------------------------------
-- 14. Respawns wait for a player, and a refused spawn is retried (Axum report)
--------------------------------------------------------------------------------
-- The 2026-11-04 trace: harvest, swim off, the timer fires with nobody near, the engine
-- refuses the spawn (invalid object, address 0), the mod counted it as done and forgot
-- the spot. Back at the spot: nothing, forever. Fe1eNinamu24 saw it on the rare Axum.
section("14. respawn waits for a player; refused spawns are retried")

quiesce()
world.player = { X = 0, Y = 0, Z = 0 }
local ax = addNode("BP_AxumBioprintCulture_Cage", 3100, 0, 0, false)
tick()                                    -- seen standing
removeNode(ax)                            -- harvested (the cage is destroyed)
tick()                                    -- queued with the player right there
world.player = { X = 5e7, Y = 0, Z = 0 }  -- swims far away
CLOCK.t = CLOCK.t + 61                    -- timer runs out while away
tick(3)
check("nothing spawns while no player is near", spawnsAt(3100) == 0,
      spawnsAt(3100) .. " spawns with nobody there")
world.player = { X = 0, Y = 0, Z = 0 }    -- comes back
tick()
check("not on the first scan back (area still streaming)", spawnsAt(3100) == 0,
      spawnsAt(3100) .. " spawns on arrival")
tick()
check("respawns once the player has settled in range", spawnsAt(3100) == 1,
      spawnsAt(3100) .. " spawns after settling")

-- The engine refuses the spawn: retry, do not forget.
quiesce()
local ax2 = addNode("BP_AxumBioprintCulture_Cage", 3300, 0, 0, false)
tick()
removeNode(ax2)
tick()
CLOCK.t = CLOCK.t + 61
world.spawnInvalid = true
reset()
tick()
check("a refused spawn is attempted", got("BeginSpawn") == 1 and spawnsAt(3300) == 0,
      got("BeginSpawn") .. " attempts, " .. spawnsAt(3300) .. " finished")
world.spawnInvalid = false
tick()
check("no retry before the retry delay", spawnsAt(3300) == 0, spawnsAt(3300) .. " spawns")
CLOCK.t = CLOCK.t + 11
tick()
check("the spot is retried, not forgotten", spawnsAt(3300) == 1,
      spawnsAt(3300) .. " spawns after the retry")

--------------------------------------------------------------------------------
-- 15. A fresh node at a recycled address is not mistaken for a far-away one
--------------------------------------------------------------------------------
-- Positions are cached by actor address and trusted for up to a minute. The engine
-- reuses addresses, so a replacement could inherit a far-away actor's cached position,
-- look out of range, leave its spot "empty", and get a second node spawned on top. The
-- mod now seeds the cache with the position it spawned at.
section("15. recycled address + spawn trace")

quiesce()
cfgT.Trace = "axum"
local far15 = addNode("BP_ResourceDeposit_Titanium", 9000000, 0, 0, false)
local cage15 = addNode("BP_AxumBioprintCulture_Cage", 3500, 0, 0, false)
tick()                                     -- both cached; the cage is seen standing
removeNode(far15) removeNode(cage15)       -- far one streams out, cage harvested
tick()                                     -- cage spot queued
CLOCK.t = CLOCK.t + 16
world.recycleAddr = far15.__addr           -- the replacement reuses the far actor's address
local inList0 = logsMatching("is in the engine's list this scan")
tick()                                     -- spawns the replacement
tick()                                     -- must see it standing, not "far away"
check("trace confirms the spawned node is in the engine's list",
      logsMatching("is in the engine's list this scan") == inList0 + 1,
      logsMatching("is in the engine's list this scan") - inList0)
CLOCK.t = CLOCK.t + 16
tick(2)
check("no second node stacked on a recycled address", spawnsAt(3500) == 1,
      spawnsAt(3500) .. " spawns at the spot")

-- The other trace outcome: the engine removes the replacement before the next scan.
local cage15b = addNode("BP_AxumBioprintCulture_Cage", 3700, 0, 0, false)
tick()
removeNode(cage15b)
tick()
CLOCK.t = CLOCK.t + 16
local notIn0 = logsMatching("is NOT in the engine's list")
tick()                                     -- spawns
world.nodes[#world.nodes] = nil            -- the game deletes it straight away
tick()
check("trace reports a replacement the engine removed",
      logsMatching("is NOT in the engine's list") == notIn0 + 1,
      logsMatching("is NOT in the engine's list") - notIn0)
cfgT.Trace = ""

--------------------------------------------------------------------------------
-- 16. Switching a resource off is not a harvest
--------------------------------------------------------------------------------
-- Seen in the 2026-11-04 menu test: Titanium OFF made every standing Titanium node look
-- harvested and queued. Had it stayed off until they came due, each would have had a
-- second node spawned on top of it.
section("16. switching a resource off is not a harvest")

quiesce()
local ti16 = addNode("BP_ResourceDeposit_Titanium", 3900, 0, 0, false)
tick()                                    -- seen standing, in the snapshot
local function writeSavedRaw(body)
    local f = assert(realopen(SAVED_PATH, "w")) f:write(body) f:close()
end
writeSavedRaw("return { Enabled = true, RespawnSeconds = 15, Titanium = false }\n")
CLOCK.t = CLOCK.t + 60                    -- settings TTL: the OFF is picked up
tick(4)
CLOCK.t = CLOCK.t + 60
tick(4)
check("no node stacked on a standing node of a switched-off resource", spawnsAt(3900) == 0,
      spawnsAt(3900) .. " spawns while the node was still there")
check("the node itself is untouched", ti16.__alive == true, "node was destroyed")
writeSaved(15)                            -- back on (Titanium = true)
CLOCK.t = CLOCK.t + 60
tick(2)
removeNode(ti16)
tick()
CLOCK.t = CLOCK.t + 16
tick(2)
check("after switching it back on, a real harvest still respawns", spawnsAt(3900) == 1,
      spawnsAt(3900) .. " spawns")

--------------------------------------------------------------------------------
-- 17. A node that streams out is not a harvest
--------------------------------------------------------------------------------
-- 2026-11-05 in game: nodes dropped out of the engine's list while the player was still
-- inside 150m, just because the area streamed out, and were queued as "harvested". One
-- respawned while its original was still streamed out, a duplicate in waiting. A
-- vanish now counts only if the node was seen breaking first, or a player is within
-- harvest range (50m).
section("17. streaming out is not a harvest")

quiesce()
-- 102m away: inside the 150m scan range, outside the 50m harvest range.
local st17 = addNode("BP_ResourceDeposit_Celestine", 10200, 0, 0, false)
writeSaved(15)
CLOCK.t = CLOCK.t + 60
tick()                                    -- seen standing
removeNode(st17)                          -- streams out: no flags, just gone
tick()
CLOCK.t = CLOCK.t + 61
tick(3)
check("a node that streamed out is not respawned", spawnsAt(10200) == 0,
      spawnsAt(10200) .. " spawns for a node nobody harvested")
world.nodes[#world.nodes + 1] = st17      -- the original streams back in
tick(2)
check("so there is no duplicate when the original streams back", spawnsAt(10200) == 0,
      spawnsAt(10200) .. " spawns")

-- Same distance, but the node is seen breaking first: that is a harvest.
local h17 = addNode("BP_ResourceDeposit_Celestine", 10600, 0, 0, false)
tick()                                    -- seen standing
h17.bActorIsBeingDestroyed = true         -- harvested: lingers flagged for a while
h17.bHasBeenGathered = true
tick()                                    -- seen breaking -> queued
removeNode(h17)                           -- then the dying actor goes
tick()
CLOCK.t = CLOCK.t + 16
tick(2)
check("a node seen breaking still respawns, even 100m away", spawnsAt(10600) == 1,
      spawnsAt(10600) .. " spawns")

-- 2026-11-05 re-check in game: a husk handed back already gathered by a save load was
-- remembered as "seen breaking"; restored in place, then streamed out later, it was
-- counted as a harvest. Only a node seen standing first and then breaking counts.
local load17 = addNode("BP_ResourceDeposit_Celestine", 11000, 0, 0, true)  -- gathered on load
tick()                                    -- flagged husk (refill-on-load queues it)
CLOCK.t = CLOCK.t + 16
tick(2)                                   -- restored in place (no longer gathered)
local before17 = spawnsAt(11000)
tick()                                    -- seen standing intact
-- A deposit's husk is replaced by a fresh node rather than un-flagged; whichever stands
-- on the spot now is what streams out.
for _, a in ipairs(world.nodes) do
    if a.__alive and a.K2_GetActorLocation().X == 11000 then removeNode(a) break end
end                                       -- streams out, 110m away
tick()
CLOCK.t = CLOCK.t + 61
tick(3)
check("a load-restored husk that later streams out is not re-harvested",
      spawnsAt(11000) == before17, (spawnsAt(11000) - before17) .. " extra spawns")

--------------------------------------------------------------------------------
section("summary")
realprint(string.format("  %d passed, %d failed", passes, failures))

if failures > 0 then
    realprint("")
    realprint("-- mod output --")
    for _, line in ipairs(logs) do realprint("  " .. line) end
end

return failures
