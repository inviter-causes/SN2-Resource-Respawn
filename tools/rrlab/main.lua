-- RRLab: TEMPORARY test mod written by the RR agent (2026-11-05). Not part of any release.
-- Driven by cmd.txt (one "<id> <verb> <args>" per line), results appended to out.txt.
-- "<id> do <file.lua>" runs a script from this folder with the LAB helpers in scope.
-- Delete the whole RRLab folder when the investigation is over.

local UEHelpers = require("UEHelpers")
local DIR = "A:/SteamLibrary/steamapps/common/Subnautica2/Subnautica2/Binaries/Win64/ue4ss/Mods/RRLab/"
local CMD, OUT = DIR .. "cmd.txt", DIR .. "out.txt"

LAB = {}
local L = LAB

function L.out(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    local s = table.concat(parts, " ")
    local f = io.open(OUT, "a")
    if f then f:write(os.date("%H:%M:%S "), s, "\n"); f:close() end
    print("[RRLab] " .. s .. "\n")
end
local out = L.out

function L.try(fn, ...)
    local ok, v = pcall(fn, ...)
    if ok then return v end
    return nil, v
end
local try = L.try

local function u32(n) return (n or 0) % 4294967296 end
function L.guidStr(g)
    local ok, s = pcall(function()
        return string.format("%08X-%08X-%08X-%08X", u32(g.A), u32(g.B), u32(g.C), u32(g.D))
    end)
    return ok and s or ("?" .. tostring(g))
end

function L.name(o)
    return try(function() return o:GetFName():ToString() end) or tostring(o)
end
function L.cls(o)
    return try(function() return o:GetClass():GetFName():ToString() end) or "?"
end
function L.valid(o)
    if o == nil then return false end
    return try(function() return o:IsValid() end) == true
end

function L.pc() return UEHelpers.GetPlayerController() end
function L.wco() return UEHelpers.GetWorldContextObject() end
function L.cm()
    local pc = L.pc()
    local c = pc and try(function() return pc.CheatManager end)
    if L.valid(c) then return c end
    c = FindFirstOf("SN2CheatManager")
    if L.valid(c) then return c end
    return nil
end

function L.ploc()
    local pc = L.pc()
    local pawn = pc and try(function() return pc.Pawn end)
    if not L.valid(pawn) then return nil end
    local v = pawn:K2_GetActorLocation()
    return { X = v.X, Y = v.Y, Z = v.Z }
end
function L.aloc(a)
    local v = a:K2_GetActorLocation()
    return { X = v.X, Y = v.Y, Z = v.Z }
end
function L.dist(a, b)
    local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function L.sub()
    local s = FindFirstOf("UWEWorldPopSubsystem")
    if L.valid(s) then return s end
    return nil
end

-- guid string -> gather state value, from UWEWorldPopSubsystem.ResourceInstanceGatherStates
function L.gatherIndex()
    local idx, n = {}, 0
    local s = L.sub()
    if not s then return idx, -1 end
    pcall(function()
        s.ResourceInstanceGatherStates:ForEach(function(k, v)
            idx[L.guidStr(k:get())] = v:get()
            n = n + 1
        end)
    end)
    return idx, n
end
function L.timerIndex()
    local idx = {}
    local s = L.sub()
    if not s then return idx end
    pcall(function()
        s.RespawnTimers:ForEach(function(k, v) idx[L.guidStr(k:get())] = v:get() end)
    end)
    return idx
end

local cmds = {}
L.cmds = cmds

cmds.ping = function() out("pong") end

cmds.where = function()
    local p = L.ploc()
    if p then out(string.format("player at (%.0f, %.0f, %.0f)", p.X, p.Y, p.Z)) else out("no pawn") end
    out("world:", L.name(L.wco()), "cheat manager:", L.cm() and L.cls(L.cm()) or "none")
end

cmds.load = function(slot, cp)
    local c = L.cm(); if not c then out("no cheat manager"); return end
    c:LoadGame(slot or "savegame_8", cp or "")
    out("LoadGame called", slot, cp)
end
cmds.continue = function()
    local c = L.cm(); if not c then out("no cheat manager"); return end
    c:ContinueGame(); out("ContinueGame called")
end
cmds.save = function(i)
    local c = L.cm(); if not c then out("no cheat manager"); return end
    c:SaveGame(tonumber(i)); out("SaveGame called", i)
end
cmds.warp = function(x, y, z)
    local c = L.cm(); if not c then out("no cheat manager"); return end
    c:Warp(tonumber(x), tonumber(y), tonumber(z)); out("Warp called", x, y, z)
end
cmds.quit = function()
    local ksl = UEHelpers.GetKismetSystemLibrary()
    out("quitting")
    ksl:QuitGame(L.wco(), L.pc(), 0, false)
end

cmds["do"] = function(file)
    local chunk, err = loadfile(DIR .. file)
    if not chunk then out("loadfile failed:", err); return end
    chunk()
end

local function run(line)
    local words = {}
    for w in line:gmatch("%S+") do words[#words + 1] = w end
    local id = table.remove(words, 1)
    local verb = table.remove(words, 1)
    out(">> " .. line)
    local fn = verb and cmds[verb]
    if not fn then
        out("unknown command:", tostring(verb))
    else
        local ok, err = xpcall(function() fn(table.unpack(words)) end, debug.traceback)
        if not ok then out("ERROR:", err) end
    end
    out("<<done " .. tostring(id) .. ">>")
end

do
    local f = io.open(CMD, "w"); if f then f:close() end
    out("RRLab loaded")
end

LoopAsync(1000, function()
    local f = io.open(CMD, "r")
    if not f then return false end
    local txt = f:read("*a"); f:close()
    if txt and txt:match("%S") then
        local w = io.open(CMD, "w"); if w then w:close() end
        for line in txt:gmatch("[^\r\n]+") do
            if line:match("%S") then
                ExecuteInGameThread(function() run(line) end)
            end
        end
    end
    return false
end)
