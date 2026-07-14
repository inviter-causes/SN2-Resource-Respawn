-- ResourceRespawn — round 4: the SPAWN EXPERIMENT (diagnostic, opt-in via cfg.Probe)
--
-- What rounds 1-3 established:
--   * Harvesting a deposit DESTROYS the actor. Editing the corpse cannot work — that is
--     why every previous attempt failed, no matter how it was written.
--   * UWEWorldPopResourceBaseActor has no reset/respawn function.
--   * The whole /Script/UWEWorldPopulation2 module exposes almost no callable API: the
--     resource subsystem has 0 functions, the "global resources storage" has 0, the
--     octree has 0. (Creatures get RequestSpawnManagedCreature; resources get nothing.)
--   * The octree holds the world-gen SEED table (10329 entries, unchanged by a harvest),
--     not a gathered-registry we could edit.
--
-- Therefore: stop trying to revive the dead node. SPAWN A NEW ONE.
--
-- We know the node's class and its exact transform before it dies. UGameplayStatics
-- exposes BeginDeferredActorSpawnFromClass + FinishSpawningActor as callable UFunctions.
-- So: capture (class, location, rotation) while the node is alive, wait, then spawn a
-- fresh instance of the same class at the same spot.
--
-- This round does exactly that, once, and reports whether it worked.
--
-- Output: <game>/Binaries/Win64/ue4ss/Mods/ResourceRespawn/probe4.txt
--
-- Usage: cfg.Probe = true, deploy, load a save, harvest a MINED DEPOSIT, then WAIT ~20s
--        while looking at the spot. Watch whether the node reappears. Then quit.

local UEHelpers = require("UEHelpers")

local M = {}

local OUT_PATH    = "./ue4ss/Mods/ResourceRespawn/probe4.txt"
local WATCH_MAX   = 8
local SPAWN_DELAY = 3     -- scans to wait after the harvest before spawning (~15s at 5s)
local GIVE_UP     = 48

local scans, done = 0, false
local watched     = {}
local pending     = nil   -- { cls, name, x,y,z, pitch,yaw,roll, atScan }
local lines = {}

local function w(s) lines[#lines + 1] = tostring(s) end

local function safe(fn, fallback)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return fallback
end

local function fname(o) return safe(function() return o:GetFName():ToString() end, "?") end
local function fullname(o) return safe(function() return o:GetFullName() end, "?") end

local function flush(log)
    local f = io.open(OUT_PATH, "w")
    if f then
        f:write(table.concat(lines, "\n") .. "\n")
        f:close()
        log("PROBE4: wrote " .. #lines .. " lines -> " .. OUT_PATH)
    else
        for _, l in ipairs(lines) do log(l) end
    end
end

-- ===== the experiment ======================================================

local function attemptSpawn(p, log)
    w("")
    w("== SPAWN ATTEMPT ==")
    w("   class    : " .. p.name)
    w("   location : " .. string.format("(%.1f, %.1f, %.1f)", p.x, p.y, p.z))
    w("   rotation : " .. string.format("(p=%.1f, y=%.1f, r=%.1f)", p.pitch, p.yaw, p.roll))

    local gs = safe(function() return UEHelpers.GetGameplayStatics() end, nil)
    local kml = safe(function() return UEHelpers.GetKismetMathLibrary() end, nil)
    local wco = safe(function() return UEHelpers.GetWorldContextObject() end, nil)

    w("   GameplayStatics    : " .. (gs and fullname(gs) or "!! NOT FOUND"))
    w("   KismetMathLibrary  : " .. (kml and fullname(kml) or "!! NOT FOUND"))
    w("   WorldContextObject : " .. (wco and fullname(wco) or "!! NOT FOUND"))
    if not (gs and kml and wco) then
        w("   ABORT: missing a prerequisite")
        return
    end

    -- Build the FTransform. Passing Lua tables for struct args is supported by UE4SS.
    local xform = safe(function()
        return kml:MakeTransform(
            { X = p.x, Y = p.y, Z = p.z },
            { Pitch = p.pitch, Yaw = p.yaw, Roll = p.roll },
            { X = 1.0, Y = 1.0, Z = 1.0 })
    end, nil)
    if not xform then
        w("   ABORT: MakeTransform failed")
        return
    end
    w("   transform built    : ok")

    -- ESpawnActorCollisionHandlingMethod::AlwaysSpawn = 1
    -- ESpawnActorScaleMethod::MultiplyWithRoot = 0
    local actor = safe(function()
        return gs:BeginDeferredActorSpawnFromClass(wco, p.cls, xform, 1, nil, 0)
    end, nil)

    if not actor then
        w("   BeginDeferredActorSpawnFromClass -> nil  (FAILED)")
        w("")
        w("   If this failed, the class may refuse deferred spawning, or the signature")
        w("   differs on this engine build. Next thing to try: hook the gather event and")
        w("   spawn from there, or call the spawner rules directly.")
        return
    end
    w("   BeginDeferredActorSpawnFromClass -> " .. fullname(actor))

    local finished = safe(function()
        return gs:FinishSpawningActor(actor, xform, 0)
    end, nil)
    w("   FinishSpawningActor -> " .. (finished and fullname(finished) or "nil"))

    local final = finished or actor
    w("")
    w("   RESULT:")
    w("     IsValid          = " .. tostring(safe(function() return final:IsValid() end, "?")))
    w("     bHasBeenGathered = " .. tostring(safe(function() return final.bHasBeenGathered end, "?")))
    w("     bHidden          = " .. tostring(safe(function() return final.bHidden end, "?")))
    w("     collision        = " .. tostring(safe(function() return final.bActorEnableCollision end, "?")))
    local loc = safe(function() return final:K2_GetActorLocation() end, nil)
    w("     location         = " .. (loc and string.format("(%.1f, %.1f, %.1f)", loc.X, loc.Y, loc.Z) or "?"))

    w("")
    w("   >>> LOOK AT THE SPOT IN GAME. Did the node reappear? That is the answer. <<<")
    log("PROBE4: spawn attempted — LOOK AT THE SPOT, did the node come back?")
end

-- ===== entry point =========================================================

function M.run(actors, log)
    if done or not actors or #actors == 0 then return end
    scans = scans + 1

    -- 3. Fire the spawn once the delay has elapsed.
    if pending and (scans - pending.atScan) >= SPAWN_DELAY then
        done = true
        w("=== ResourceRespawn probe 4 — spawn experiment ===")
        w("harvest seen at scan " .. pending.atScan .. ", spawning at scan " .. scans)
        attemptSpawn(pending, log)

        -- Sanity check: how many live, un-gathered nodes of this class sit near the spot
        -- now? If the spawn worked there should be one where the harvested node was.
        w("")
        w("== UN-GATHERED NODES OF THIS CLASS WITHIN 10m OF THE SPOT ==")
        local hits = 0
        for _, a in ipairs(FindAllOf("UWEWorldPopResourceBaseActor") or {}) do
            local cls = safe(function() return a:GetClass() end, nil)
            local g   = safe(function() return a.bHasBeenGathered end, nil)
            local al  = safe(function() return a:K2_GetActorLocation() end, nil)
            if cls and al and g == false and fname(cls) == fname(pending.cls) then
                local dx, dy, dz = al.X - pending.x, al.Y - pending.y, al.Z - pending.z
                if (dx*dx + dy*dy + dz*dz) < (1000 * 1000) then
                    hits = hits + 1
                    w("   " .. fullname(a))
                end
            end
        end
        w("   count: " .. hits .. (hits > 0 and "   <- a fresh node is standing there" or "   <- nothing there"))
        flush(log)
        return
    end

    -- 1. Did a watched node just get harvested? Capture everything before it dies.
    if not pending then
        for _, e in pairs(watched) do
            local g = safe(function() return e.actor.bHasBeenGathered end, nil)
            if g == true then
                pending = {
                    cls    = e.cls,
                    name   = e.cn,
                    x = e.x, y = e.y, z = e.z,
                    pitch = e.pitch, yaw = e.yaw, roll = e.roll,
                    atScan = scans,
                }
                log("PROBE4: harvest captured (" .. e.cn .. ") — spawning a replacement in ~"
                    .. (SPAWN_DELAY * 5) .. "s. Keep looking at the spot.")
                return
            end
        end
    end

    -- 2. Watch the nearest intact deposits, recording class + transform while alive.
    local pc   = safe(function() return FindFirstOf("PlayerController") end, nil)
    local pawn = pc and safe(function() return pc.Pawn end, nil)
    local ploc = pawn and safe(function() return pawn:K2_GetActorLocation() end, nil)
    if ploc then
        local cand = {}
        for _, a in ipairs(actors) do
            local cls = safe(function() return a:GetClass() end, nil)
            local cn  = cls and fname(cls) or ""
            local g   = safe(function() return a.bHasBeenGathered end, nil)
            local al  = safe(function() return a:K2_GetActorLocation() end, nil)
            if g == false and al and cls then
                local dx, dy, dz = al.X - ploc.X, al.Y - ploc.Y, al.Z - ploc.Z
                cand[#cand + 1] = {
                    a = a, cls = cls, cn = cn, loc = al,
                    d2 = dx*dx + dy*dy + dz*dz,
                    dep = cn:lower():find("resourcedeposit", 1, true) ~= nil,
                }
            end
        end
        table.sort(cand, function(x, y)
            if x.dep ~= y.dep then return x.dep end
            return x.d2 < y.d2
        end)

        watched = {}
        for i = 1, math.min(WATCH_MAX, #cand) do
            local c = cand[i]
            local rot = safe(function() return c.a:K2_GetActorRotation() end, nil)
            local addr = safe(function() return tostring(c.a:GetAddress()) end, nil)
            if addr and rot then
                watched[addr] = {
                    actor = c.a, cls = c.cls,
                    cn = c.cn .. string.format("  [%.0fm]", math.sqrt(c.d2) / 100),
                    x = c.loc.X, y = c.loc.Y, z = c.loc.Z,
                    pitch = rot.Pitch, yaw = rot.Yaw, roll = rot.Roll,
                }
            end
        end

        if scans == 1 or scans % 12 == 0 then
            local names = {}
            for _, e in pairs(watched) do names[#names + 1] = e.cn end
            log("PROBE4: watching -> " .. table.concat(names, " | "))
        end
    end

    if scans >= GIVE_UP then
        done = true
        w("=== ResourceRespawn probe 4 — no harvest seen, nothing to spawn ===")
        flush(log)
    end
end

return M
