-- remember every standing resource actor within LAB.SNAPR m (id -> class, location)
local L = LAB
local p = L.ploc()
LAB.SNAPSHOT = {}
local n = 0
for _, a in ipairs(FindAllOf("UWEWorldPopResourceBaseActor") or {}) do
    local ok, loc = pcall(L.aloc, a)
    if ok and L.dist(p, loc) < (LAB.SNAPR or 60) * 100 and not L.try(function() return a.bHasBeenGathered end) then
        local id = L.guidStr(a.ResourceId)
        LAB.SNAPSHOT[id] = { c = L.cls(a), loc = loc }
        n = n + 1
    end
end
L.out("snapshot:", n, "standing actors within", LAB.SNAPR or 60, "m")
