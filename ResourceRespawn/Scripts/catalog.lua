-- ResourceRespawn - CATALOG probe (diagnostic, opt-in via cfg.Catalog)
--
-- Purpose: identify a resource the mod does NOT yet support - what to match on, and
-- whether there is any harvest state to hook.
--
-- v5, after standing at a Mineralized Clinker proved it is NEITHER a
-- UWEWorldPopResourceBaseActor NOR a StaticMeshActor (the crosshair named it 2m away;
-- the nearest scanned actor was scenery 18m away). RESOURCES.md's old "it is a
-- StaticMeshActor" note was wrong. So its class is unknown - this version finds it:
--
--   1. free guesses first: FindAllOf on a list of likely blueprint class names;
--   2. then a gated sweep of FindAllOf("Actor") - the exact call deepScan (main.lua)
--      made every scan throughout 2.0.0 development without a crash, using the same
--      light reads only (location, class name). That is how Fulgurite and
--      NeedleSharkNeedles were discovered, so the surface is proven in a live world.
--
-- SAFETY - this probe crashed the game three times before reaching this shape:
--   Crash 1: FindAllOf("Actor") at the main menu (transient menu actors).
--            -> bail unless world-pop resources exist; the sweep never runs in a lobby.
--   Crash 2: scanning during the post-load streaming burst; IsValid() is not enough.
--            -> stability gate: nothing is scanned until the player has stood still
--               for STABLE_RUNS consecutive scans.
--   Crash 3: walking the class graph (GetSuperStruct / ForEachProperty / per-FProperty
--            reads) died even standing still in a loaded world.
--            -> NO class-graph reflection, ever. Only reads proven over hours of 2.0.0
--               development: FindAllOf, IsValid, K2_GetActorLocation, GetClass+GetFName,
--               GetFullName on instances, and direct property reads.
--   Also: dump ONCE per stillness (not every scan), and stream each line to disk with
--   a flush, so if it ever dies again catalog.txt itself shows how far it got.
--
-- It does NOT touch, spawn or destroy anything. Read-only.
--
-- Output: <game>/Binaries/Win64/ue4ss/Mods/ResourceRespawn/catalog.txt
--
-- Usage: cfg.Catalog = true, deploy, LOAD A SAVE, swim right up to the resource, then
--        STAND STILL ON IT until the log says the dump is written (~15-20s). To dump
--        another spot, swim there and stand still again.

local M = {}

local OUT_PATH    = "./ue4ss/Mods/ResourceRespawn/catalog.txt"
local SHOW_ACTORS = 12      -- report this many nearest actors
local RANGE_UU    = 3000    -- only actors within 30m are candidates for the resource
local SKIP_UU     = 100     -- skip the player-attached cluster (held tool, body) within 1m
local STABLE_RUNS = 3       -- consecutive stationary runs before the world is trusted
local MOVE_UU     = 100     -- moving more than 1m between runs resets the streak

-- Free first shots: likely class names for the Mineralized Clinker. A wrong name just
-- returns an empty list; a right one identifies it without the sweep.
local CANDIDATES = {
    "BP_MineralizedClinker_C",
    "BP_Clinker_C",
    "BP_TroiliteNode_C",
    "BP_TroiliteDeposit_C",
    "BP_ResourceDeposit_Troilite_C",
    "BP_MetalFarmClinker_C",
    "MineralizedClinker_C",
}

local function safe(fn, fallback)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return fallback
end

-- An actor is safe to look at only if the engine still considers it valid.
local function isValid(a) return safe(function() return a:IsValid() end, false) == true end

local function fname(o) return safe(function() return o:GetFName():ToString() end, "?") end
local function fullname(o) return safe(function() return o:GetFullName() end, "?") end

-- ===== player location (self-contained, mirrors main.lua) ==================

local function playerLoc()
    local pc = safe(function() return FindFirstOf("PlayerController") end, nil)
    if not pc then return nil end
    local pawn = safe(function() return pc.Pawn end, nil)
    if not pawn then return nil end
    if not isValid(pawn) then return nil end
    local loc = safe(function() return pawn:K2_GetActorLocation() end, nil)
    if loc then return loc.X, loc.Y, loc.Z end
    return nil
end

-- ===== the dump ============================================================

local warnedNoPlayer, warnedNoWorld = false, false
local lastX, lastY, lastZ = nil, nil, nil
local streak = 0

function M.run(log)
    local px, py, pz = playerLoc()
    if not px then
        if not warnedNoPlayer then
            warnedNoPlayer = true
            log("CATALOG: player location not ready yet")
        end
        streak, lastX = 0, nil
        return
    end
    warnedNoPlayer = false

    -- Guard 1: only proceed in a real gameplay world (crash #1 was the lobby's actors).
    local resourceBase = safe(function() return FindAllOf("UWEWorldPopResourceBaseActor") end, {}) or {}
    if #resourceBase == 0 then
        if not warnedNoWorld then
            warnedNoWorld = true
            log("CATALOG: no world-pop resources present (lobby/menu?) - skipping until a save is loaded")
        end
        streak, lastX = 0, nil
        return
    end
    warnedNoWorld = false

    -- Guard 2: the stability gate (crash #2 was the post-load streaming burst). Scan only
    -- when the streak REACHES the threshold - once per stillness, not every scan after.
    local moved = true
    if lastX then
        local dx, dy, dz = px - lastX, py - lastY, pz - lastZ
        moved = (dx * dx + dy * dy + dz * dz) > (MOVE_UU * MOVE_UU)
    end
    lastX, lastY, lastZ = px, py, pz
    if moved then
        streak = 0
        return
    end
    streak = streak + 1
    if streak ~= STABLE_RUNS then
        if streak == 1 then
            log("CATALOG: hold still - the dump is written after ~"
                .. (STABLE_RUNS * 5) .. "s of standing on the spot")
        end
        return
    end

    -- Trusted. Announce BEFORE scanning so the log shows the dump began even if it dies.
    log("CATALOG: scanning now...")

    -- The file is streamed line by line and flushed, so a crash mid-dump leaves the
    -- lines written so far - the file itself then says where it stopped.
    local f = io.open(OUT_PATH, "w")
    if not f then
        log("CATALOG: could not open " .. OUT_PATH .. " for writing")
        return
    end
    local function w(s) f:write(tostring(s) .. "\n") f:flush() end

    w("=== ResourceRespawn catalog - nearby actors ===")
    w(string.format("player at (%.1f, %.1f, %.1f)", px, py, pz))

    -- Phase 1: the free class-name guesses.
    w("")
    w("candidate class guesses:")
    local guessed = 0
    for _, name in ipairs(CANDIDATES) do
        local list = safe(function() return FindAllOf(name) end, nil)
        if list and #list > 0 then
            guessed = guessed + 1
            local bestD2, best = nil, nil
            for _, a in ipairs(list) do
                if isValid(a) then
                    local loc = safe(function() return a:K2_GetActorLocation() end, nil)
                    if loc then
                        local dx, dy, dz = loc.X - px, loc.Y - py, loc.Z - pz
                        local d2 = dx * dx + dy * dy + dz * dz
                        if not bestD2 or d2 < bestD2 then bestD2, best = d2, a end
                    end
                end
            end
            w(string.format("    HIT  %-34s %d instance(s)%s", name, #list,
                bestD2 and string.format(", nearest %.1fm", math.sqrt(bestD2) / 100) or ""))
            if best then w("         nearest: " .. fullname(best)) end
        else
            w(string.format("    miss %s", name))
        end
    end
    if guessed == 0 then w("    (no guess matched - the sweep below is the answer)") end

    -- Phase 2: the gated sweep. Same call + same light reads as main.lua's deepScan
    -- (location, class name), which ran every scan during 2.0.0 dev without a crash.
    local actors = safe(function() return FindAllOf("Actor") end, {}) or {}
    local near = {}
    for _, a in ipairs(actors) do
        if isValid(a) then
            local loc = safe(function() return a:K2_GetActorLocation() end, nil)
            if loc then
                local dx, dy, dz = loc.X - px, loc.Y - py, loc.Z - pz
                local d2 = dx * dx + dy * dy + dz * dz
                if d2 >= SKIP_UU * SKIP_UU and d2 <= RANGE_UU * RANGE_UU then
                    local cn = fname(safe(function() return a:GetClass() end, nil) or {})
                    if cn ~= "?" and cn:sub(1, 3) ~= "GC_" then
                        near[#near + 1] = { a = a, cn = cn, d2 = d2 }
                    end
                end
            end
        end
    end
    table.sort(near, function(x, y) return x.d2 < y.d2 end)

    w("")
    w(string.format("%d actors swept, %d within %dm, showing nearest %d",
        #actors, #near, RANGE_UU / 100, math.min(SHOW_ACTORS, #near)))
    w("")
    w("The resource you are standing on is the nearest entry - usually #1.")

    local shown = math.min(SHOW_ACTORS, #near)
    for i = 1, shown do
        local e = near[i]
        w("")
        w(string.format("--- #%d  [%.1fm]  %s ---", i, math.sqrt(e.d2) / 100, e.cn))

        if not isValid(e.a) then
            w("    !! actor went invalid before it could be read - skipped")
        else
            w("actor : " .. fullname(e.a))

            -- Opportunistic, safe-wrapped direct reads. UE4SS does NOT return nil for a
            -- property that does not exist - it returns an empty object wrapper - so a
            -- read only counts when the TYPE is right (a real boolean, a real mesh name).
            local g = safe(function() return e.a.bHasBeenGathered end, nil)
            if type(g) == "boolean" then
                w("kind  : world-pop resource (has bHasBeenGathered - the mod CAN hook this)")
                w("state : bHasBeenGathered = " .. tostring(g))
            else
                local cmp = safe(function() return e.a.StaticMeshComponent end, nil)
                local mesh = cmp and safe(function() return cmp.StaticMesh end, nil) or nil
                local meshName = mesh and fullname(mesh) or "?"
                if meshName:find("StaticMesh ", 1, true) == 1 then
                    w("kind  : static mesh prop (no gathered state)")
                    w("mesh  : " .. meshName)
                else
                    w("kind  : other (no gathered flag, no static mesh - inspect the class name)")
                end
            end
        end
    end

    f:close()
    local head = shown > 0
        and string.format(" (nearest: %s [%.1fm])", near[1].cn, math.sqrt(near[1].d2) / 100)
        or ""
    log(string.format("CATALOG: %d actors swept, wrote %d within %dm -> catalog.txt%s",
        #actors, #near, RANGE_UU / 100, head))
end

return M
