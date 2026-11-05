-- state of the picked id, plus any standing resource actor within 3m of the picked spot
local L = LAB
local id = LAB.PICKED_ID or "?"
local gidx = L.gatherIndex()
local tidx = L.timerIndex()
local s = L.sub()
local pend = 0
pcall(function() s.PendingRespawnActors:ForEach(function() pend = pend + 1 end) end)
local withId, standingId, nearSpot = 0, 0, {}
for _, a in ipairs(FindAllOf("UWEWorldPopResourceBaseActor") or {}) do
    local g = L.try(function() return L.guidStr(a.ResourceId) end)
    local gathered = L.try(function() return a.bHasBeenGathered end)
    local dying = L.try(function() return a.bActorIsBeingDestroyed end)
    if g == id then
        withId = withId + 1
        if not gathered and not dying then standingId = standingId + 1 end
    end
    if LAB.PICKED_LOC then
        local ok, loc = pcall(L.aloc, a)
        if ok and L.dist(loc, LAB.PICKED_LOC) < 300 then
            nearSpot[#nearSpot + 1] = string.format("%s(%s g=%s d=%s)", L.cls(a), g and g:sub(1, 8) or "?", tostring(gathered), tostring(dying))
        end
    end
end
L.out(string.format("id %s: gs=%s timer=%s pending=%d actorsWithId=%d standing=%d | at spot: %s", id, tostring(gidx[id]),
    tostring(tidx[id]), pend, withId, standingId, table.concat(nearSpot, ", ")))
