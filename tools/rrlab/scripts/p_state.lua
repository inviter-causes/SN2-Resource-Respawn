-- compact snapshot: subsystem map sizes, timers, gather-state histogram, quartz actor counts by gathered flag
local L = LAB
local s = L.sub(); if not s then L.out("no sub"); return end
local function cnt(p) local n = 0; pcall(function() s[p]:ForEach(function() n = n + 1 end) end); return n end
L.out(string.format("toRespawn=%d timers=%d pending=%d gatherStates=%d", cnt("ResourcesToRespawn"), cnt("RespawnTimers"), cnt("PendingRespawnActors"), cnt("ResourceInstanceGatherStates")))
local hist = {}
pcall(function() s.ResourceInstanceGatherStates:ForEach(function(k, v) local x = v:get(); hist[x] = (hist[x] or 0) + 1 end) end)
for v, c in pairs(hist) do L.out("  gs value", v, "x", c) end
pcall(function() s.RespawnTimers:ForEach(function(k, v) L.out("  timer", L.guidStr(k:get()), string.format("%.1f", v:get())) end) end)
pcall(function() s.ResourcesToRespawn:ForEach(function(a, b) local e = b or a; L.out("  toRespawn", L.guidStr(e.get and e:get() or e)) end) end)
pcall(function() s.PendingRespawnActors:ForEach(function(k, v) L.out("  pending", L.guidStr(k:get())) end) end)
local all = FindAllOf("UWEWorldPopResourceBaseActor") or {}
local n, g, dying = 0, 0, 0
for _, a in ipairs(all) do
    n = n + 1
    if L.try(function() return a.bHasBeenGathered end) then g = g + 1 end
    if L.try(function() return a.bActorIsBeingDestroyed end) then dying = dying + 1 end
end
L.out(string.format("actors=%d gathered=%d dying=%d", n, g, dying))
