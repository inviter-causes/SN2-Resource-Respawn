local L = LAB
local p = L.ploc()
local gidx = L.gatherIndex()
local all = FindAllOf("UWEWorldPopResourceBaseActor") or {}
local h = {}
for _, a in ipairs(all) do
    local c = L.cls(a)
    local r = h[c] or { n = 0, gs = 0, gathered = 0, near = 1e18, zero = 0 }
    h[c] = r
    r.n = r.n + 1
    local g = L.try(function() return L.guidStr(a.ResourceId) end) or "?"
    if g == "00000000-00000000-00000000-00000000" then r.zero = r.zero + 1 end
    if gidx[g] ~= nil then r.gs = r.gs + 1 end
    if L.try(function() return a.bHasBeenGathered end) then r.gathered = r.gathered + 1 end
    local ok, loc = pcall(L.aloc, a)
    if ok and p then r.near = math.min(r.near, L.dist(p, loc)) end
end
for c, r in pairs(h) do
    L.out(string.format("%-46s n=%3d inGatherStates=%3d gathered=%3d zeroId=%3d nearest=%.0fm", c, r.n, r.gs, r.gathered, r.zero, r.near / 100))
end
