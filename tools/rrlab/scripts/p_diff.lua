-- which snapshotted ids have gather state 1 / a timer / no standing actor now
local L = LAB
local gidx, tidx = L.gatherIndex(), L.timerIndex()
local standing = {}
for _, a in ipairs(FindAllOf("UWEWorldPopResourceBaseActor") or {}) do
    if not L.try(function() return a.bHasBeenGathered end) and not L.try(function() return a.bActorIsBeingDestroyed end) then
        standing[L.guidStr(a.ResourceId)] = (standing[L.guidStr(a.ResourceId)] or 0) + 1
    end
end
local shown = 0
for id, e in pairs(LAB.SNAPSHOT or {}) do
    if gidx[id] ~= 0 or tidx[id] or not standing[id] then
        shown = shown + 1
        L.out(string.format("  %s %s gs=%s timer=%s standing=%s at (%.0f,%.0f,%.0f)", id, e.c, tostring(gidx[id]), tostring(tidx[id]), tostring(standing[id] or 0), e.loc.X, e.loc.Y, e.loc.Z))
    end
end
L.out("changed:", shown)
