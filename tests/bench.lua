-- Allocation benchmark for one scan.
--
-- Loads main.lua from the given Scripts dir against a mock world and measures how much
-- garbage a single scan produces, with the collector held off so nothing is reclaimed
-- mid-measurement. Used to compare two revisions of the mod.
--
-- FindAllOf hands back the same table every call on purpose: the engine's own allocation
-- is identical for both revisions, and holding it constant isolates what the scan body
-- itself throws away.
--
-- Driven by tests/bench.py.

local SCRIPTS, NODES, TICKS = ...
NODES = tonumber(NODES) or 800
TICKS = tonumber(TICKS) or 50

package.path = SCRIPTS .. "/?.lua;" .. package.path

local CLOCK = { t = 100000 }
os.time = function() return CLOCK.t end

local world = { nodes = {}, player = { X = 0, Y = 0, Z = 0 } }

local function makeActor(name, x, y, z, addr)
    local full  = "BlueprintGeneratedClass /Game/Res/" .. name .. "." .. name .. "_C"
    local fname = { ToString = function() return name end }
    local cls   = {
        GetFName    = function() return fname end,
        GetFullName = function() return full end,
    }
    local a
    a = {
        bHasBeenGathered       = false,
        bActorIsBeingDestroyed = false,
        ResourceId = { A = 0, B = 0, C = 0, D = 0 },
        GetAddress            = function() return addr end,
        K2_GetActorLocation   = function() return { X = x, Y = y, Z = z } end,
        K2_GetActorRotation   = function() return { Pitch = 0, Yaw = 0, Roll = 0 } end,
        GetClass              = function() return cls end,
        IsValid               = function() return true end,
        OnRep_HasBeenGathered = function() end,
        K2_DestroyActor       = function() end,
    }
    return a
end

-- All far from the player, which is the realistic case: almost every resource actor in the
-- world is kilometres away and only ever hits the cull path.
for i = 1, NODES do
    world.nodes[i] = makeActor("BP_ResourceDeposit_Titanium",
                               1000000 + i * 10, 0, 0, 4096 + i * 8)
end

FindAllOf = function(cls)
    if cls ~= "UWEWorldPopResourceBaseActor" then return {} end
    return world.nodes
end

FindFirstOf = function(cls)
    if cls ~= "PlayerController" then return nil end
    return { Pawn = { K2_GetActorLocation = function() return world.player end } }
end

StaticFindObject = function(p) return { __path = p } end

package.loaded["UEHelpers"] = {
    GetGameplayStatics = function()
        return {
            BeginDeferredActorSpawnFromClass = function() return {} end,
            FinishSpawningActor              = function() end,
        }
    end,
    GetKismetMathLibrary  = function() return { MakeTransform = function() return {} end } end,
    GetWorldContextObject = function() return {} end,
}

package.loaded["lang"] = {
    code = "en",
    s    = function(k) return tostring(k) end,
    res  = function(k, w) return tostring(k) .. tostring(w) end,
}

local realprint = print
print = function() end

local TICK
LoopAsync           = function(_, fn) TICK = fn end
ExecuteInGameThread = function(fn) fn() end

dofile(SCRIPTS .. "/main.lua")
assert(TICK, "main.lua never registered a LoopAsync callback")

-- Warm the location cache so steady state is measured, not first-sight cost.
for _ = 1, 20 do TICK() end

collectgarbage("collect")
collectgarbage("stop")
local before = collectgarbage("count")
for _ = 1, TICKS do TICK() end
local after = collectgarbage("count")
collectgarbage("restart")

print = realprint
return (after - before) / TICKS   -- KB of garbage per scan
